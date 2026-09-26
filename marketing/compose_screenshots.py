#!/opt/homebrew/bin/python3
"""Compose localized App Store screenshots from raw simulator captures.

Usage: compose_screenshots.py [--ipad] [locale ...]   (defaults to every marketing/listing/<locale>.json)

--ipad composes the 13-inch iPad set from marketing/raw/<locale>/ipad/<screen>.png into
marketing/appstore-ipad/<locale>/, skipping entries with no capture; geometry scales with the canvas.

Raw 1320x2868 captures live in marketing/raw/<locale>/<screen>.png (produced by marketing/shoot.sh,
which launches the localized app in PX_DEMO mode on an iPhone 17 Pro Max simulator). Each entry in
marketing/listing/<locale>.json names its screen, headline and subhead; the capture is set into a
rounded device frame on the brand gradient and the captions are typeset above it.

An entry with "panel": "beforeafter" needs no capture: it names a "before" and an "after" image from the
app's DemoArt asset catalog (real outputs of the app's preset prompts) and a "tag", the preset's English
title, which is looked up in the app's String Catalog so the badge reads exactly like the button in the
localized app; it is drawn as two photo cards under the captions. The locale's top-level "labels" hold the
localized "before" and "after" badge words.
"""

import glob
import json
import os
import sys
import unicodedata

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
DEMO_ART = os.path.join(ROOT, "..", "iOS", "Pixie", "Pixie", "Resources", "Assets.xcassets", "DemoArt")
STRING_CATALOG = os.path.join(ROOT, "..", "iOS", "Pixie", "Pixie", "Resources", "Localizable.xcstrings")
APP_LANGUAGE = {"de-DE": "de", "es-ES": "es", "es-MX": "es", "fr-FR": "fr", "it": "it", "ja": "ja", "ko": "ko",
                "pl": "pl", "pt-BR": "pt-BR", "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant"}
CARD_BORDER = 10
BADGE_FILL = (18, 14, 34, 215)
TAG_FILL = (255, 255, 255, 255)
TAG_TEXT = (92, 52, 170)
RAW = os.path.join(ROOT, "raw")
APPSTORE = os.path.join(ROOT, "appstore")
LISTING = os.path.join(ROOT, "listing")

SIZE = (1320, 2868)
PHONE_LEFT = 92
PHONE_RIGHT = 1226
PHONE_TOP = 530
PHONE_RADIUS = 96
PHONE_BORDER = 5
TEXT_MARGIN = 70
HEADLINE_TOP = 150
HEADLINE_SIZE = 116
HEADLINE_LEADING = 136
HEADLINE_MIN_SIZE = 84
HEADLINE_TO_SUBHEAD = 60
SUBHEAD_SIZE = 54
SUBHEAD_LEADING = 68
SUBHEAD_MIN_SIZE = 40
CAPTION_BOTTOM_GAP = 70
GRADIENT_TOP = (60, 38, 99)
GRADIENT_BOTTOM = (10, 8, 24)
GLOW = (120, 70, 190)
HEADLINE_COLOR = (255, 255, 255)
SUBHEAD_COLOR = (200, 171, 239)
FRAME_COLOR = (18, 14, 34)

SANS_PATH = "/System/Library/Fonts/SFNS.ttf"
SANS_FALLBACK = "/System/Library/Fonts/HelveticaNeue.ttc"
CJK_FACES = {
    "ja": [("/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc", 0), ("/System/Library/Fonts/Hiragino Sans GB.ttc", 2)],
    "ko": [("/System/Library/Fonts/AppleSDGothicNeo.ttc", 6)],
    "zh-Hans": [("/System/Library/Fonts/PingFang.ttc", 0), ("/System/Library/Fonts/Hiragino Sans GB.ttc", 2)],
    "zh-Hant": [("/System/Library/Fonts/PingFang.ttc", 0), ("/System/Library/Fonts/Hiragino Sans GB.ttc", 2)],
}
for _family in ("ja", "zh-Hans", "zh-Hant"):
    CJK_FACES[_family].append(("/System/Library/Fonts/AppleSDGothicNeo.ttc", 6))
CJK_FACES["ko"].append(("/System/Library/Fonts/Hiragino Sans GB.ttc", 2))

CJK_BREAK_AFTER = "。、，；：！？ "
CJK_NO_LINE_START = "。、，；：！？」』）】〕〉》｝・ー～…‥,.;:!?)]}"


def cjk_family(locale):
    for key in CJK_FACES:
        if locale.lower().startswith(key.lower()):
            return key
    return None


def _existing(path):
    if os.path.exists(path):
        return path
    folder, name = os.path.split(path)
    want = unicodedata.normalize("NFC", name)
    for entry in os.listdir(folder):
        if unicodedata.normalize("NFC", entry) == want:
            return os.path.join(folder, entry)
    return None


def load_fonts(locale):
    family = cjk_family(locale)
    if family:
        for path, index in CJK_FACES[family]:
            real = _existing(path)
            if real:
                def face(size, _p=real, _i=index):
                    return ImageFont.truetype(_p, size, index=_i)
                return face, face
        raise SystemExit(f"no CJK font found for {locale}")

    def sans(weight, fallback_index):
        def face(size):
            if os.path.exists(SANS_PATH):
                font = ImageFont.truetype(SANS_PATH, size)
                font.set_variation_by_name(weight)
                return font
            return ImageFont.truetype(SANS_FALLBACK, size, index=fallback_index)
        return face

    return sans("Bold", 2), sans("Semibold", 1)


def has_cjk(text):
    return any(unicodedata.east_asian_width(ch) in "WF" for ch in text)


def wrap(text, font, max_width, cjk):
    if cjk and cjk != "ko" and has_cjk(text):
        return wrap_cjk(text, font, max_width)
    return wrap_words(text, font, max_width)


def wrap_words(text, font, max_width):
    lines, current = [], ""
    for word in text.split():
        trial = f"{current} {word}".strip()
        if font.getlength(trial) <= max_width or not current:
            current = trial
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    return balance(lines, font, max_width)


def balance(lines, font, max_width):
    """Two ragged lines read better when their lengths are close; a one-word last line reads as a typo."""
    if len(lines) != 2:
        return lines
    words = " ".join(lines).split()
    best = lines
    for split in range(1, len(words)):
        first, second = " ".join(words[:split]), " ".join(words[split:])
        if font.getlength(first) > max_width or font.getlength(second) > max_width:
            continue
        if abs(font.getlength(first) - font.getlength(second)) < abs(font.getlength(best[0]) - font.getlength(best[1])):
            best = [first, second]
    return best


def cjk_segments(text):
    segments, current = [], ""
    for ch in text:
        current += ch
        if ch in CJK_BREAK_AFTER:
            segments.append(current)
            current = ""
    if current:
        segments.append(current)
    return segments


def wrap_cjk(text, font, max_width):
    lines, current = [], ""
    for segment in cjk_segments(text):
        trial = current + segment
        if font.getlength(trial.rstrip()) <= max_width:
            current = trial
            continue
        if current:
            lines.append(current.rstrip())
            current = ""
        if font.getlength(segment.rstrip()) <= max_width:
            current = segment
            continue
        for ch in segment:
            if font.getlength(current + ch) <= max_width or not current or ch in CJK_NO_LINE_START:
                current += ch
            else:
                lines.append(current)
                current = ch
    if current.rstrip():
        lines.append(current.rstrip())
    return [line.lstrip() for line in lines]


def overflows(lines, font, max_width):
    return any(font.getlength(line) > max_width for line in lines)


def orphaned(lines, cjk):
    return bool(cjk) and cjk != "ko" and len(lines) > 1 and len(lines[-1].strip()) < 4


def fit(text, make_font, max_width, cjk, size, min_size, leading, max_lines, step):
    base = size
    while True:
        font = make_font(size)
        lines = wrap(text, font, max_width, cjk)
        if (len(lines) <= max_lines and not overflows(lines, font, max_width) and not orphaned(lines, cjk)) or size <= min_size:
            return font, lines, round(leading * size / base)
        size -= step


def ascent_offset(font):
    return font.getbbox("H")[1]


def background():
    height = SIZE[1]
    t = np.linspace(0, 1, height)[:, None, None]
    top = np.array(GRADIENT_TOP, dtype=np.float32)
    bottom = np.array(GRADIENT_BOTTOM, dtype=np.float32)
    plane = top * (1 - t) + bottom * t
    canvas = np.repeat(plane, SIZE[0], axis=1)
    yy, xx = np.mgrid[0:height, 0:SIZE[0]]
    glow = np.exp(-(((xx - SIZE[0] / 2) / (SIZE[0] * 0.47)) ** 2 + ((yy - 120) / 520) ** 2))
    canvas += glow[..., None] * (np.array(GLOW, dtype=np.float32) - top) * 0.55
    return Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8))


def framed_phone(capture):
    width = PHONE_RIGHT - PHONE_LEFT
    height = round(capture.height * width / capture.width)
    screen = capture.resize((width, height), Image.LANCZOS)
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), PHONE_RADIUS, fill=255)
    frame = Image.new("RGBA", (width + 2 * PHONE_BORDER, height + 2 * PHONE_BORDER), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle(
        (0, 0, frame.width - 1, frame.height - 1), PHONE_RADIUS + PHONE_BORDER, fill=FRAME_COLOR + (255,)
    )
    frame.paste(screen, (PHONE_BORDER, PHONE_BORDER), mask)
    return frame


def paste_with_shadow(canvas, phone, xy):
    x, y = xy
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x - 12, y - 4, x + phone.width + 12, y + phone.height + 40), PHONE_RADIUS + 12, fill=(0, 0, 0, 150)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(phone, (x, y))


def typeset(entry, locale, fonts):
    headline_font_fn, subhead_font_fn = fonts
    cjk = cjk_family(locale)
    width = SIZE[0] - 2 * TEXT_MARGIN
    headline = fit(entry["headline"], headline_font_fn, width, cjk, HEADLINE_SIZE, HEADLINE_MIN_SIZE, HEADLINE_LEADING, 2, 4)
    subhead = fit(entry["subhead"], subhead_font_fn, width, cjk, SUBHEAD_SIZE, SUBHEAD_MIN_SIZE, SUBHEAD_LEADING, 2, 2)
    return headline, subhead


def caption_bottom(headline, subhead):
    _, headline_lines, headline_leading = headline
    _, subhead_lines, subhead_leading = subhead
    return HEADLINE_TOP + headline_leading * len(headline_lines) + HEADLINE_TO_SUBHEAD + subhead_leading * len(subhead_lines)


def compose(entry, locale, fonts, phone_top):
    capture = Image.open(raw_path(locale, entry["screen"])).convert("RGB")
    assert capture.size == SIZE, f"{locale}/{entry['screen']}: unexpected capture size {capture.size}"
    canvas = background().convert("RGBA")
    draw_captions(canvas, entry, locale, fonts)
    paste_with_shadow(canvas, framed_phone(capture), (PHONE_LEFT - PHONE_BORDER, phone_top))
    return canvas.crop((0, 0) + SIZE).convert("RGB")


def app_string(key, locale):
    """The app's own translation of `key` for a store locale; English locales use the key itself."""
    language = APP_LANGUAGE.get(locale)
    if language is None:
        return key
    with open(STRING_CATALOG) as fh:
        entry = json.load(fh)["strings"].get(key)
    try:
        return entry["localizations"][language]["stringUnit"]["value"]
    except (TypeError, KeyError):
        raise SystemExit(f"no {language} translation of {key!r} in the app's String Catalog")


def demo_art(name):
    folder = os.path.join(DEMO_ART, f"{name}.imageset")
    for entry in sorted(os.listdir(folder)):
        if entry.lower().endswith((".jpg", ".jpeg", ".png")):
            return Image.open(os.path.join(folder, entry)).convert("RGB")
    raise SystemExit(f"no image in {folder}")


def photo_card(image, width, radius):
    height = round(image.height * width / image.width)
    photo = image.resize((width, height), Image.LANCZOS)
    card = Image.new("RGBA", (width + 2 * CARD_BORDER, height + 2 * CARD_BORDER), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle((0, 0, card.width - 1, card.height - 1), radius + CARD_BORDER, fill=(255, 255, 255, 255))
    mask = Image.new("L", photo.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius, fill=255)
    card.paste(photo, (CARD_BORDER, CARD_BORDER), mask)
    return card


def paste_card(canvas, card, xy, angle=0.0):
    if angle:
        card = card.rotate(angle, resample=Image.BICUBIC, expand=True)
    x, y = xy
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    silhouette = Image.new("RGBA", card.size, (0, 0, 0, 170))
    shadow.paste(silhouette, (x, y + 36), card.split()[3])
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(38)))
    canvas.alpha_composite(card, (x, y))
    return card


def draw_pill(canvas, text, font, center, fill, color, pad_x, pad_y, sparkle=False):
    draw = ImageDraw.Draw(canvas)
    left, top, right, bottom = font.getbbox(text)
    text_height = bottom - top
    icon = round(text_height * 1.05) if sparkle else 0
    gap = round(icon * 0.45) if sparkle else 0
    width, height = right - left + icon + gap + 2 * pad_x, text_height + 2 * pad_y
    x0, y0 = round(center[0] - width / 2), round(center[1] - height / 2)
    draw.rounded_rectangle((x0, y0, x0 + width, y0 + height), height // 2, fill=fill)
    if sparkle:
        draw_sparkle(draw, (x0 + pad_x + icon / 2, y0 + height / 2), icon / 2, color)
    draw.text((x0 + pad_x + icon + gap - left, y0 + pad_y - top), text, font=font, fill=color)


def draw_sparkle(draw, center, radius, color):
    cx, cy = center
    waist = radius * 0.28
    draw.polygon([
        (cx, cy - radius), (cx + waist, cy - waist), (cx + radius, cy), (cx + waist, cy + waist),
        (cx, cy + radius), (cx - waist, cy + waist), (cx - radius, cy), (cx - waist, cy - waist),
    ], fill=color)


def compose_before_after(entry, locale, fonts, top, labels):
    """The result fills the panel; the original sits on top of its lower-left corner as a
    small tilted inset, so both stay fully readable in the search-result thumbnail."""
    canvas = background().convert("RGBA")
    draw_captions(canvas, entry, locale, fonts)
    width, height = SIZE
    after_image, before_image = demo_art(entry["after"]), demo_art(entry["before"])
    aspect = after_image.width / after_image.height
    after_width = min(round(width * 0.88), round((height - top - height * 0.13) * aspect))
    radius = round(after_width * 0.04)
    after_card = photo_card(after_image, after_width, radius)
    inset = photo_card(before_image, round(after_width * 0.4), radius)
    after_x = min(width - round(width * 0.03) - after_card.width, round((width - after_card.width) / 2 + width * 0.05))
    inset_x = max(round(width * 0.025), after_x - round(inset.width * 0.2))
    content_height = after_card.height + round(inset.height * 0.4) + round(height * 0.02)
    after_y = top + max(round(height * 0.005), (height - top - content_height - round(height * 0.03)) // 2)
    after_bottom = after_y + after_card.height
    paste_card(canvas, after_card, (after_x, after_y))
    inset_y = after_bottom - round(inset.height * 0.62)
    placed_inset = paste_card(canvas, inset, (inset_x, inset_y), angle=5)

    headline_face, subhead_face = fonts
    badge_font = subhead_face(round(width * 0.03))
    pad_x, pad_y = round(width * 0.02), round(width * 0.011)
    draw_pill(canvas, labels["after"], badge_font,
              (after_x + after_card.width - round(width * 0.1), after_y + round(width * 0.065)),
              BADGE_FILL, (255, 255, 255), pad_x, pad_y)
    draw_pill(canvas, labels["before"], badge_font,
              (inset_x + placed_inset.width / 2, inset_y + round(width * 0.075)),
              BADGE_FILL, (255, 255, 255), pad_x, pad_y)
    tag_font = headline_face(round(width * 0.042))
    inset_right = inset_x + placed_inset.width
    tag_center_x = (inset_right + width) / 2
    draw_pill(canvas, app_string(entry["tag"], locale), tag_font,
              (tag_center_x, after_bottom + round(height * 0.052)),
              TAG_FILL, TAG_TEXT, round(width * 0.04), round(width * 0.02), sparkle=True)
    return canvas.crop((0, 0) + SIZE).convert("RGB")


def draw_captions(canvas, entry, locale, fonts):
    draw = ImageDraw.Draw(canvas)
    headline, subhead = typeset(entry, locale, fonts)
    headline_font, headline_lines, headline_leading = headline
    subhead_font, subhead_lines, subhead_leading = subhead
    y = HEADLINE_TOP
    cap = ascent_offset(headline_font)
    for index, line in enumerate(headline_lines):
        x = (SIZE[0] - headline_font.getlength(line)) / 2
        draw.text((x, y + index * headline_leading - cap), line, font=headline_font, fill=HEADLINE_COLOR)
    y += headline_leading * len(headline_lines) + HEADLINE_TO_SUBHEAD
    cap = ascent_offset(subhead_font)
    for index, line in enumerate(subhead_lines):
        x = (SIZE[0] - subhead_font.getlength(line)) / 2
        draw.text((x, y + index * subhead_leading - cap), line, font=subhead_font, fill=SUBHEAD_COLOR)


def is_before_after(entry):
    return entry.get("panel") == "beforeafter"


def locales_present():
    return sorted(os.path.splitext(os.path.basename(p))[0] for p in glob.glob(os.path.join(LISTING, "*.json")))


IPAD_SIZE = (2064, 2752)


def use_ipad_geometry():
    """Scale the iPhone layout to the iPad canvas; the wider screen gets a slimmer top band."""
    global SIZE, RAW, APPSTORE, PHONE_LEFT, PHONE_RIGHT, PHONE_TOP, PHONE_RADIUS, TEXT_MARGIN, HEADLINE_TOP
    scale = IPAD_SIZE[0] / SIZE[0]
    SIZE = IPAD_SIZE
    RAW = os.path.join(RAW, "%s", "ipad")
    APPSTORE = os.path.join(ROOT, "appstore-ipad")
    PHONE_LEFT, PHONE_RIGHT = round(92 * scale), IPAD_SIZE[0] - round(92 * scale)
    PHONE_TOP = round(PHONE_TOP * 0.95)
    PHONE_RADIUS = round(PHONE_RADIUS * 0.6)
    TEXT_MARGIN = round(TEXT_MARGIN * scale)
    HEADLINE_TOP = round(HEADLINE_TOP * 0.9)


def raw_path(locale, screen):
    folder = RAW % locale if "%s" in RAW else os.path.join(RAW, locale)
    return os.path.join(folder, f"{screen}.png")


def main(argv):
    if argv and argv[0] == "--ipad":
        use_ipad_geometry()
        argv = argv[1:]
    for locale in argv or locales_present():
        with open(os.path.join(LISTING, f"{locale}.json")) as fh:
            listing = json.load(fh)
        entries = [e for e in listing["screenshots"] if is_before_after(e) or os.path.exists(raw_path(locale, e["screen"]))]
        if not entries:
            continue
        fonts = load_fonts(locale)
        out_dir = os.path.join(APPSTORE, locale)
        os.makedirs(out_dir, exist_ok=True)
        phone_top = max([PHONE_TOP] + [caption_bottom(*typeset(e, locale, fonts)) + CAPTION_BOTTOM_GAP for e in entries])
        for stale in glob.glob(os.path.join(out_dir, "*.png")):
            os.remove(stale)
        for entry in entries:
            if is_before_after(entry):
                image = compose_before_after(entry, locale, fonts, phone_top, listing["labels"])
            else:
                image = compose(entry, locale, fonts, phone_top)
            image.save(os.path.join(out_dir, f"{entry['file']}.png"), optimize=True)
            print(f"{os.path.basename(APPSTORE)}/{locale}/{entry['file']}.png")


if __name__ == "__main__":
    main(sys.argv[1:])
