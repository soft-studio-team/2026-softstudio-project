#!/usr/bin/env python3
"""Generate a 1-2 page middle-school-level wishkit login PDF."""

from __future__ import annotations

import os
import sys

_TOOLS = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", ".pdf-tools")
)
if os.path.isdir(_TOOLS):
    sys.path.insert(0, _TOOLS)

from reportlab.lib.colors import HexColor, white
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    Flowable,
    KeepTogether,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

FONT_PATH = "/System/Library/Fonts/Supplemental/AppleGothic.ttf"
OUT_NAME = "wishkit-로그인-쉬운설명.pdf"

INK = HexColor("#2F2A26")
MUTED = HexColor("#6F655C")
PAPER = HexColor("#F7F4EE")
ACCENT = HexColor("#6B7F6A")
CREAM = HexColor("#E6D9C8")
LINE = HexColor("#D9D2C6")
NAVY = HexColor("#3D3834")
GREEN = HexColor("#E7EDE4")


class HLine(Flowable):
    def __init__(self, color=LINE, thickness=0.8):
        super().__init__()
        self.color = color
        self.thickness = thickness
        self.height = thickness

    def wrap(self, availWidth, availHeight):
        self.width = availWidth
        return availWidth, self.height

    def draw(self):
        self.canv.setStrokeColor(self.color)
        self.canv.setLineWidth(self.thickness)
        self.canv.line(0, 0, self.width, 0)


def styles():
    s = {}
    s["kicker"] = ParagraphStyle(
        "kicker", fontName="Ko", fontSize=9, textColor=CREAM, leading=12
    )
    s["title"] = ParagraphStyle(
        "title", fontName="Ko", fontSize=18, textColor=white, leading=23
    )
    s["sub"] = ParagraphStyle(
        "sub", fontName="Ko", fontSize=10, textColor=HexColor("#E8E0D4"), leading=14
    )
    s["h"] = ParagraphStyle(
        "h",
        fontName="Ko",
        fontSize=12,
        textColor=NAVY,
        leading=16,
        spaceBefore=6,
        spaceAfter=3,
        wordWrap="CJK",
    )
    s["body"] = ParagraphStyle(
        "body",
        fontName="Ko",
        fontSize=10.2,
        textColor=INK,
        leading=15.4,
        wordWrap="CJK",
        spaceAfter=3,
    )
    s["bullet"] = ParagraphStyle(
        "bullet",
        fontName="Ko",
        fontSize=11,
        textColor=INK,
        leading=16.5,
        wordWrap="CJK",
        leftIndent=2,
        spaceAfter=1,
    )
    s["cell"] = ParagraphStyle(
        "cell", fontName="Ko", fontSize=9.5, textColor=INK, leading=14, wordWrap="CJK"
    )
    s["cellHead"] = ParagraphStyle(
        "cellHead", fontName="Ko", fontSize=9.5, textColor=NAVY, leading=14, wordWrap="CJK"
    )
    s["stepT"] = ParagraphStyle(
        "stepT",
        fontName="Ko",
        fontSize=9,
        textColor=white,
        alignment=TA_CENTER,
        leading=12,
        wordWrap="CJK",
    )
    s["stepB"] = ParagraphStyle(
        "stepB",
        fontName="Ko",
        fontSize=8.5,
        textColor=INK,
        alignment=TA_CENTER,
        leading=12.5,
        wordWrap="CJK",
    )
    s["boxT"] = ParagraphStyle(
        "boxT", fontName="Ko", fontSize=11, textColor=NAVY, leading=15, wordWrap="CJK"
    )
    s["boxB"] = ParagraphStyle(
        "boxB", fontName="Ko", fontSize=10.5, textColor=INK, leading=16, wordWrap="CJK"
    )
    s["foot"] = ParagraphStyle(
        "foot", fontName="Ko", fontSize=8, textColor=MUTED, leading=12, wordWrap="CJK"
    )
    return s


def P(text, style):
    return Paragraph(text.replace("\n", "<br/>"), style)


def header_footer(canvas, doc):
    canvas.saveState()
    w, h = A4
    canvas.setFillColor(PAPER)
    canvas.rect(0, 0, w, 11 * mm, fill=1, stroke=0)
    canvas.setStrokeColor(LINE)
    canvas.setLineWidth(0.4)
    canvas.line(16 * mm, 11 * mm, w - 16 * mm, 11 * mm)
    canvas.setFillColor(MUTED)
    canvas.setFont("Ko", 8)
    canvas.drawString(16 * mm, 5 * mm, "wishkit 로그인 쉬운 설명  ·  중학생도 읽기 쉬운 버전")
    canvas.drawRightString(w - 16 * mm, 5 * mm, str(doc.page))
    canvas.restoreState()


def build():
    pdfmetrics.registerFont(TTFont("Ko", FONT_PATH))
    st = styles()
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, OUT_NAME)
    W = A4[0] - 32 * mm
    doc = SimpleDocTemplate(
        out,
        pagesize=A4,
        leftMargin=16 * mm,
        rightMargin=16 * mm,
        topMargin=10 * mm,
        bottomMargin=13 * mm,
        title="wishkit 로그인 쉬운 설명",
        author="softstudio",
    )
    story = []

    banner = Table(
        [
            [P("WISHKIT  ·  쉬운 설명", st["kicker"])],
            [P("로그인이 어떻게 되나요?", st["title"])],
            [
                P(
                    "어려운 말은 빼고, 우리 앱이 계정을 다루는 방법을 짧게 정리했어요.",
                    st["sub"],
                )
            ],
        ],
        colWidths=[W],
    )
    banner.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), NAVY),
                ("LEFTPADDING", (0, 0), (-1, -1), 16),
                ("RIGHTPADDING", (0, 0), (-1, -1), 16),
                ("TOPPADDING", (0, 0), (0, 0), 9),
                ("TOPPADDING", (0, 1), (0, 1), 3),
                ("TOPPADDING", (0, 2), (0, 2), 3),
                ("BOTTOMPADDING", (0, 2), (0, 2), 9),
                ("BOTTOMPADDING", (0, 0), (0, 1), 2),
            ]
        )
    )
    story.append(banner)
    story.append(Spacer(1, 7))

    story.append(P("먼저, 학교로 생각해 보면", st["h"]))
    story.append(HLine(ACCENT))
    story.append(Spacer(1, 4))
    story.append(
        P(
            "wishkit에 들어가려면 <b>내 자리</b>가 필요해요. "
            "이메일은 출석부의 이름이고, 비밀번호는 사물함 비밀번호예요. "
            "아이디(@이름)는 친구들이 부르는 <b>별명 명찰</b>이에요.",
            st["body"],
        )
    )

    jobs = Table(
        [
            [
                P("<b>문지기</b><br/>Firebase Auth", st["cellHead"]),
                P("<b>사물함</b><br/>Firestore", st["cellHead"]),
                P("<b>사진첩</b><br/>Storage", st["cellHead"]),
            ],
            [
                P("이 사람이 맞는지 확인해요. 비밀번호는 여기에만 있어요.", st["cell"]),
                P("이름, 아이디, 위시리스트, 친구 목록을 넣어요.", st["cell"]),
                P("프로필 사진, 리뷰 사진을 넣어요.", st["cell"]),
            ],
        ],
        colWidths=[W / 3.0] * 3,
    )
    jobs.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), CREAM),
                ("BACKGROUND", (0, 1), (-1, 1), PAPER),
                ("GRID", (0, 0), (-1, -1), 0.4, LINE),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story.append(jobs)
    story.append(Spacer(1, 5))

    story.append(P("가입부터 들어가기까지", st["h"]))
    story.append(HLine(ACCENT))
    story.append(Spacer(1, 4))
    labels = ["1. 가입", "2. 메일 확인", "3. 내 자리 만들기", "4. 시작"]
    notes = [
        "이름, 아이디,\n이메일, 비밀번호",
        "메일 속 링크를\n꼭 눌러요",
        "그때 아이디가\n내 것이 돼요",
        "위시리스트로\n들어가요",
    ]
    n = 4
    w = W / n
    steps = Table(
        [
            [P(x, st["stepT"]) for x in labels],
            [P(x, st["stepB"]) for x in notes],
        ],
        colWidths=[w] * n,
    )
    steps.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, 0), ACCENT),
                ("BACKGROUND", (1, 0), (1, 0), NAVY),
                ("BACKGROUND", (2, 0), (2, 0), ACCENT),
                ("BACKGROUND", (3, 0), (3, 0), NAVY),
                ("BACKGROUND", (0, 1), (-1, 1), PAPER),
                ("GRID", (0, 0), (-1, -1), 0.35, LINE),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, 0), 7),
                ("BOTTOMPADDING", (0, 0), (-1, 0), 7),
                ("TOPPADDING", (0, 1), (-1, 1), 6),
                ("BOTTOMPADDING", (0, 1), (-1, 1), 6),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(steps)
    story.append(Spacer(1, 4))
    story.append(
        P(
            "메일을 확인하기 전에는 <b>아직 앱 계정이 아니에요.</b> "
            "링크를 눌러야 “이 이메일이 정말 내 것”인지 알 수 있어요. "
            "그다음에야 내 위시리스트 자리가 생깁니다.",
            st["body"],
        )
    )
    story.append(
        P(
            "이미 가입했다면 이메일과 비밀번호만 넣으면 다시 들어올 수 있어요. 앱을 껐다 켜도 문지기가 기억합니다.",
            st["body"],
        )
    )

    story.append(P("까먹었을 때 · 나가고 싶을 때", st["h"]))
    story.append(HLine(ACCENT))
    story.append(Spacer(1, 4))
    help_rows = [
        [
            P("<b>비밀번호를 잊었어요</b>", st["cellHead"]),
            P(
                "가입한 이메일을 넣으면, 새 비밀번호를 만드는 메일이 가요. "
                "앱이 비밀번호를 알려주지는 않아요.",
                st["cell"],
            ),
        ],
        [
            P("<b>이메일을 잊었어요</b>", st["cellHead"]),
            P(
                "내 아이디(@별명)를 넣으면, 이메일을 살짝 가려서 보여 줘요. "
                "예: k***m@gmail.com",
                st["cell"],
            ),
        ],
        [
            P("<b>비밀번호를 바꾸고 싶어요</b>", st["cellHead"]),
            P("마이페이지에서 지금 비밀번호를 한 번 더 확인한 뒤 바꿉니다.", st["cell"]),
        ],
        [
            P("<b>로그아웃</b>", st["cellHead"]),
            P("이 폰에서만 나가요. 계정과 위시리스트는 그대로 남아 있어요.", st["cell"]),
        ],
        [
            P("<b>탈퇴하기</b>", st["cellHead"]),
            P(
                "계정과 위시리스트가 지워지고 되돌릴 수 없어요. "
                "비밀번호를 다시 묻고, 아이디 명찰도 반납해서 다른 사람이 쓸 수 있게 해요.",
                st["cell"],
            ),
        ],
    ]
    help = Table(help_rows, colWidths=[42 * mm, W - 42 * mm])
    help.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, -1), CREAM),
                ("BACKGROUND", (1, 0), (1, -1), white),
                ("GRID", (0, 0), (-1, -1), 0.4, LINE),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 7),
                ("RIGHTPADDING", (0, 0), (-1, -1), 7),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                ("ROWBACKGROUNDS", (1, 0), (1, -1), [white, HexColor("#FBF8F3")]),
            ]
        )
    )
    story.append(KeepTogether([help]))

    story.append(P("아이디는 왜 겹치면 안 되나요?", st["h"]))
    story.append(HLine(ACCENT))
    story.append(Spacer(1, 4))
    story.append(
        P(
            "친구를 찾을 때, 팔로우할 때, 이메일을 찾을 때 우리는 <b>아이디 명찰</b>을 봐요. "
            "교실에 “민아” 명찰이 두 개면, 누구를 팔로우한 건지 헷갈리겠죠. "
            "그래서 가입할 때 이미 있는 아이디면 “이미 사용 중인 아이디예요”라고 막아요.",
            st["body"],
        )
    )
    story.append(
        P(
            "컴퓨터 안에는 사람마다 숨겨진 번호가 있어요. 팔로우는 그 번호로 저장하지만, "
            "화면에 보이는 건 아이디라서 명찰이 하나여야 엉키지 않아요.",
            st["body"],
        )
    )

    box = Table(
        [
            [P("<b>이것만 기억하면 돼요</b>", st["boxT"])],
            [
                P(
                    "1. 문지기가 “누구인지” 확인하고, 사물함에 내 물건을 넣어요.<br/>"
                    "2. 메일 확인 전에는 아직 내 자리가 없어요.<br/>"
                    "3. 아이디는 반에서 하나뿐인 명찰이에요. 겹치면 친구 기능이 헷갈려요.",
                    st["boxB"],
                )
            ],
        ],
        colWidths=[W],
    )
    box.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), GREEN),
                ("LEFTPADDING", (0, 0), (-1, -1), 12),
                ("RIGHTPADDING", (0, 0), (-1, -1), 12),
                ("TOPPADDING", (0, 0), (0, 0), 8),
                ("BOTTOMPADDING", (0, -1), (-1, -1), 9),
                ("TOPPADDING", (0, 1), (0, 1), 2),
            ]
        )
    )
    story.append(Spacer(1, 5))
    story.append(box)
    story.append(Spacer(1, 5))
    story.append(
        P(
            "구글·카카오 로그인(다른 앱 계정으로 들어가기)은 아직 없어요. "
            "지금 쓰는 방법은 이메일과 비밀번호뿐입니다. "
            "더 자세한 기술 설명은 같은 폴더의 「wishkit 로그인 구현 설명서」를 보면 됩니다.",
            st["foot"],
        )
    )

    doc.build(story, onFirstPage=header_footer, onLaterPages=header_footer)
    print(out)


if __name__ == "__main__":
    build()
