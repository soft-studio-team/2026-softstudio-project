#!/usr/bin/env python3
"""Generate wishkit login implementation PDF (Korean)."""

from __future__ import annotations

import os
import sys

_TOOLS = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", ".pdf-tools")
)
if os.path.isdir(_TOOLS):
    sys.path.insert(0, _TOOLS)

from reportlab.lib.colors import HexColor, white
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    CondPageBreak,
    Flowable,
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

FONT_PATH = "/System/Library/Fonts/Supplemental/AppleGothic.ttf"
OUT_NAME = "wishkit-로그인-구현-설명서.pdf"

INK = HexColor("#2F2A26")
MUTED = HexColor("#6F655C")
SOFT = HexColor("#B0A69C")
PAPER = HexColor("#F7F4EE")
CANVAS = HexColor("#ECECEA")
ACCENT = HexColor("#6B7F6A")
PIN = HexColor("#B86B5A")
CREAM = HexColor("#E6D9C8")
LINE = HexColor("#D9D2C6")
NAVY = HexColor("#3D3834")


class HLine(Flowable):
    def __init__(self, color=LINE, thickness=0.6, space_before=2, space_after=8):
        super().__init__()
        self.color = color
        self.thickness = thickness
        self.spaceBefore = space_before
        self.spaceAfter = space_after
        self.height = thickness

    def wrap(self, availWidth, availHeight):
        self.width = availWidth
        return availWidth, self.height

    def draw(self):
        self.canv.setStrokeColor(self.color)
        self.canv.setLineWidth(self.thickness)
        self.canv.line(0, 0, self.width, 0)


class Callout(Flowable):
    def __init__(self, title, body, styles, tint=CREAM, width=None):
        super().__init__()
        self.title = title
        self.body = body
        self.styles = styles
        self.tint = tint
        self._width = width
        self._inner = None

    def wrap(self, availWidth, availHeight):
        w = self._width or availWidth
        data = [
            [Paragraph(f"<b>{self.title}</b>", self.styles["calloutTitle"])],
            [Paragraph(self.body, self.styles["calloutBody"])],
        ]
        t = Table(data, colWidths=[w - 8])
        t.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, -1), self.tint),
                    ("LEFTPADDING", (0, 0), (-1, -1), 12),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 12),
                    ("TOPPADDING", (0, 0), (0, 0), 10),
                    ("BOTTOMPADDING", (0, -1), (-1, -1), 10),
                    ("TOPPADDING", (0, 1), (-1, 1), 2),
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("BOX", (0, 0), (-1, -1), 0, self.tint),
                    ("LEFTPADDING", (0, 0), (-1, -1), 14),
                ]
            )
        )
        self._inner = t
        iw, ih = t.wrap(w, availHeight)
        self.width, self.height = iw, ih
        return iw, ih

    def draw(self):
        self._inner.drawOn(self.canv, 0, 0)


def register_font():
    if not os.path.exists(FONT_PATH):
        raise SystemExit(f"Korean font not found: {FONT_PATH}")
    pdfmetrics.registerFont(TTFont("Ko", FONT_PATH))


def styles():
    base = getSampleStyleSheet()
    s = {}
    s["coverKicker"] = ParagraphStyle(
        "coverKicker",
        fontName="Ko",
        fontSize=11,
        textColor=CREAM,
        alignment=TA_LEFT,
        leading=16,
    )
    s["coverTitle"] = ParagraphStyle(
        "coverTitle",
        fontName="Ko",
        fontSize=28,
        textColor=white,
        alignment=TA_LEFT,
        leading=36,
        spaceAfter=8,
    )
    s["coverSub"] = ParagraphStyle(
        "coverSub",
        fontName="Ko",
        fontSize=12,
        textColor=HexColor("#E8E0D4"),
        alignment=TA_LEFT,
        leading=18,
    )
    s["h1"] = ParagraphStyle(
        "h1",
        fontName="Ko",
        fontSize=16,
        textColor=NAVY,
        leading=22,
        spaceBefore=6,
        spaceAfter=8,
        wordWrap="CJK",
    )
    s["h2"] = ParagraphStyle(
        "h2",
        fontName="Ko",
        fontSize=13,
        textColor=ACCENT,
        leading=18,
        spaceBefore=12,
        spaceAfter=6,
        wordWrap="CJK",
    )
    s["h3"] = ParagraphStyle(
        "h3",
        fontName="Ko",
        fontSize=11.5,
        textColor=INK,
        leading=16,
        spaceBefore=8,
        spaceAfter=4,
        wordWrap="CJK",
    )
    s["body"] = ParagraphStyle(
        "body",
        fontName="Ko",
        fontSize=10,
        textColor=INK,
        leading=16.2,
        alignment=TA_JUSTIFY,
        wordWrap="CJK",
        spaceAfter=6,
    )
    s["bullet"] = ParagraphStyle(
        "bullet",
        fontName="Ko",
        fontSize=10,
        textColor=INK,
        leading=15.6,
        wordWrap="CJK",
        leftIndent=2,
    )
    s["small"] = ParagraphStyle(
        "small",
        fontName="Ko",
        fontSize=8.5,
        textColor=MUTED,
        leading=13,
        wordWrap="CJK",
    )
    s["caption"] = ParagraphStyle(
        "caption",
        fontName="Ko",
        fontSize=8.5,
        textColor=MUTED,
        leading=12,
        alignment=TA_CENTER,
        spaceBefore=3,
        spaceAfter=10,
        wordWrap="CJK",
    )
    s["cell"] = ParagraphStyle(
        "cell",
        fontName="Ko",
        fontSize=8.7,
        textColor=INK,
        leading=13,
        wordWrap="CJK",
    )
    s["cellHead"] = ParagraphStyle(
        "cellHead",
        fontName="Ko",
        fontSize=8.7,
        textColor=NAVY,
        leading=13,
        wordWrap="CJK",
    )
    s["code"] = ParagraphStyle(
        "code",
        fontName="Ko",
        fontSize=8.4,
        textColor=INK,
        leading=13,
        wordWrap="CJK",
        backColor=PAPER,
        leftIndent=4,
        rightIndent=4,
    )
    s["toc"] = ParagraphStyle(
        "toc",
        fontName="Ko",
        fontSize=11,
        textColor=INK,
        leading=18,
        wordWrap="CJK",
    )
    s["calloutTitle"] = ParagraphStyle(
        "calloutTitle",
        fontName="Ko",
        fontSize=10,
        textColor=NAVY,
        leading=14,
        wordWrap="CJK",
    )
    s["calloutBody"] = ParagraphStyle(
        "calloutBody",
        fontName="Ko",
        fontSize=9.5,
        textColor=INK,
        leading=14.5,
        wordWrap="CJK",
    )
    s["footer"] = ParagraphStyle(
        "footer",
        fontName="Ko",
        fontSize=8,
        textColor=MUTED,
        alignment=TA_LEFT,
    )
    s["stepTitle"] = ParagraphStyle(
        "stepTitle",
        fontName="Ko",
        fontSize=9,
        textColor=white,
        alignment=TA_CENTER,
        leading=12,
        wordWrap="CJK",
    )
    s["stepBody"] = ParagraphStyle(
        "stepBody",
        fontName="Ko",
        fontSize=8,
        textColor=INK,
        alignment=TA_CENTER,
        leading=11.5,
        wordWrap="CJK",
    )
    return s


def P(text, style):
    return Paragraph(text.replace("\n", "<br/>"), style)


def bullets(items, st):
    flow = []
    for item in items:
        flow.append(P(f"•  {item}", st["bullet"]))
    flow.append(Spacer(1, 4))
    return flow


def table(headers, rows, st, col_widths):
    head = [P(h, st["cellHead"]) for h in headers]
    body = [[P(c, st["cell"]) for c in row] for row in rows]
    t = Table([head] + body, colWidths=col_widths, repeatRows=1)
    t.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), CREAM),
                ("TEXTCOLOR", (0, 0), (-1, 0), NAVY),
                ("FONTNAME", (0, 0), (-1, -1), "Ko"),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 7),
                ("RIGHTPADDING", (0, 0), (-1, -1), 7),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                ("GRID", (0, 0), (-1, -1), 0.4, LINE),
                ("BACKGROUND", (0, 1), (-1, -1), white),
                (
                    "ROWBACKGROUNDS",
                    (0, 1),
                    (-1, -1),
                    [white, HexColor("#FBF8F3")],
                ),
            ]
        )
    )
    return t


def step_row(labels, notes, st, width):
    n = len(labels)
    w = width / n
    title_row = [
        P(f"{i+1}. {lab}", st["stepTitle"]) for i, lab in enumerate(labels)
    ]
    note_row = [P(note, st["stepBody"]) for note in notes]
    t = Table([title_row, note_row], colWidths=[w] * n)
    cmds = [
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, 0), 8),
        ("BOTTOMPADDING", (0, 0), (-1, 0), 8),
        ("TOPPADDING", (0, 1), (-1, 1), 7),
        ("BOTTOMPADDING", (0, 1), (-1, 1), 8),
        ("BACKGROUND", (0, 1), (-1, 1), PAPER),
        ("BOX", (0, 0), (-1, -1), 0.4, LINE),
        ("INNERGRID", (0, 0), (-1, -1), 0.35, LINE),
    ]
    for i in range(n):
        cmds.append(("BACKGROUND", (i, 0), (i, 0), ACCENT if i % 2 == 0 else NAVY))
    t.setStyle(TableStyle(cmds))
    return t


def add_header_footer(canvas, doc):
    canvas.saveState()
    page = doc.page
    if page == 1:
        canvas.restoreState()
        return
    w, h = A4
    canvas.setFillColor(PAPER)
    canvas.rect(0, h - 14 * mm, w, 14 * mm, fill=1, stroke=0)
    canvas.setFillColor(INK)
    canvas.setFont("Ko", 8)
    canvas.drawString(18 * mm, h - 9 * mm, "wishkit  로그인 구현 설명서")
    canvas.setFillColor(MUTED)
    canvas.drawRightString(w - 18 * mm, h - 9 * mm, "wishlist-appversion2")
    canvas.setStrokeColor(LINE)
    canvas.setLineWidth(0.5)
    canvas.line(18 * mm, h - 14 * mm, w - 18 * mm, h - 14 * mm)

    canvas.setFillColor(PAPER)
    canvas.rect(0, 0, w, 12 * mm, fill=1, stroke=0)
    canvas.setStrokeColor(LINE)
    canvas.line(18 * mm, 12 * mm, w - 18 * mm, 12 * mm)
    canvas.setFillColor(MUTED)
    canvas.setFont("Ko", 8)
    canvas.drawString(18 * mm, 5.5 * mm, "softstudio  ·  내부 기술 문서")
    canvas.drawRightString(w - 18 * mm, 5.5 * mm, str(page - 1))
    canvas.restoreState()


def cover(st, width):
    story = []
    data = [
        [
            P("WISHKIT  ·  INTERNAL TECH NOTE", st["coverKicker"]),
        ],
        [
            P("로그인 기능과<br/>구현 방법 설명서", st["coverTitle"]),
        ],
        [
            P(
                "이메일·비밀번호 인증, 아이디 유일성, 계정 찾기·탈퇴까지<br/>"
                "wishkit이 Firebase로 계정을 다루는 방식을 한곳에 정리합니다.",
                st["coverSub"],
            )
        ],
        [
            P(
                "대상 코드  &nbsp; wishlist-appversion2 / flutter_app<br/>"
                "백엔드  &nbsp; Firebase Auth  ·  Cloud Firestore  ·  Storage<br/>"
                "작성일  &nbsp; 2026년 8월 14일",
                st["coverSub"],
            )
        ],
    ]
    t = Table(data, colWidths=[width])
    t.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), NAVY),
                ("LEFTPADDING", (0, 0), (-1, -1), 22),
                ("RIGHTPADDING", (0, 0), (-1, -1), 22),
                ("TOPPADDING", (0, 0), (0, 0), 36),
                ("TOPPADDING", (0, 1), (0, 1), 18),
                ("TOPPADDING", (0, 2), (0, 2), 8),
                ("TOPPADDING", (0, 3), (0, 3), 28),
                ("BOTTOMPADDING", (0, 0), (0, 2), 4),
                ("BOTTOMPADDING", (0, 3), (0, 3), 36),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ]
        )
    )
    story.append(t)
    story.append(Spacer(1, 16))
    story.append(
        Callout(
            "이 문서가 다루는 것",
            "회원가입, 이메일 인증, 로그인, 이메일 찾기, 비밀번호 찾기·변경, "
            "로그아웃, 계정 탈퇴, 그리고 아이디가 겹치면 팔로우가 깨지지 않게 한 이유와 구현입니다. "
            "구글·카카오 소셜 로그인은 현재 없습니다.",
            st,
        )
    )
    return story


def build():
    register_font()
    st = styles()
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, OUT_NAME)
    doc = SimpleDocTemplate(
        out,
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=20 * mm,
        bottomMargin=16 * mm,
        title="wishkit 로그인 구현 설명서",
        author="softstudio",
    )
    W = A4[0] - 36 * mm
    story = []

    # Cover uses full-bleed-ish table; first page has no header.
    story.extend(cover(st, W))
    story.append(PageBreak())

    # 1. TOC
    story.append(P("1. 목차", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    toc = [
        "2. 한 줄 요약",
        "3. 왜 Firebase를 쓰나",
        "4. 역할 나누기 — 화면 / 상태 / 저장소",
        "5. 사용자가 보는 화면과 이동 규칙",
        "6. 회원가입",
        "7. 이메일 인증",
        "8. 로그인과 세션 복원",
        "9. 이메일 찾기 · 비밀번호 찾기",
        "10. 비밀번호 변경 · 로그아웃",
        "11. 계정 탈퇴",
        "12. 아이디가 겹치면 안 되는 이유",
        "13. Firestore 데이터 구조",
        "14. 보안 규칙",
        "15. 에러 메시지",
        "16. 주요 파일",
        "17. 아직 없는 것 · 운영 시 확인할 것",
    ]
    story.extend(bullets(toc, st))

    # 2
    story.append(P("2. 한 줄 요약", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(
        P(
            "wishkit 로그인은 <b>이메일 + 비밀번호</b>만 사용합니다. "
            "누가 로그인했는지는 <b>Firebase Authentication</b>이 증명하고, "
            "이름·아이디·위시리스트·팔로우 같은 앱 데이터는 <b>Cloud Firestore</b>에 둡니다. "
            "프로필 사진과 리뷰 사진은 <b>Firebase Storage</b>에 올립니다.",
            st["body"],
        )
    )
    story.append(
        P(
            "가입 직후에는 앱에 바로 들어가지 않습니다. "
            "Firebase가 보낸 인증 메일의 링크를 누른 뒤에야 Firestore 프로필이 만들어집니다. "
            "아이디(handle, 예: @mina)는 전역에서 하나만 쓸 수 있습니다. "
            "같은 아이디가 두 명에게 붙으면 친구 찾기·팔로우·이메일 찾기가 사람을 구분하지 못합니다.",
            st["body"],
        )
    )
    story.append(
        table(
            ["구분", "쓰는 서비스", "하는 일"],
            [
                [
                    "로그인 자격 증명",
                    "Firebase Auth",
                    "이메일/비밀번호 가입·로그인, 인증 메일, 비밀번호 재설정, 계정 삭제",
                ],
                [
                    "앱 계정(프로필)",
                    "Cloud Firestore",
                    "users/{uid}, handles/{아이디}, 팔로우, 위시리스트, 알림, 리뷰",
                ],
                [
                    "파일",
                    "Firebase Storage",
                    "avatars/{uid}/… , reviews/{uid}/…",
                ],
                [
                    "기기 임시값",
                    "SharedPreferences",
                    "가입 중 이름·아이디 초안, 알림 on/off, 살까말까 로컬 보완",
                ],
            ],
            st,
            [32 * mm, 38 * mm, W - 70 * mm],
        )
    )
    story.append(P("표 1. 로그인과 계정에 쓰는 저장소", st["caption"]))

    # 3
    story.append(P("3. 왜 Firebase를 쓰나", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(
        P(
            "우리 앱 서버(파싱 엔진)는 쇼핑 링크에서 상품 정보를 읽는 역할입니다. "
            "회원 시스템·세션·비밀번호를 직접 만들지 않습니다. "
            "대신 Google Firebase 프로젝트 <b>softstudio-wishlist-app</b>에 계정을 맡깁니다.",
            st["body"],
        )
    )
    story.extend(
        bullets(
            [
                "<b>Auth</b>가 비밀번호를 해시해 보관합니다. 앱은 비밀번호를 Firestore에 저장하지 않습니다.",
                "로그인이 성공하면 Firebase가 <b>uid</b>(사용자 고유 ID)와 ID 토큰을 줍니다. 이후 Firestore 읽기/쓰기는 이 uid로 권한을 검사합니다.",
                "앱을 껐다 켜도 Firebase SDK가 세션을 유지합니다. 시작 시 currentUser가 있으면 그 세션을 이어갑니다.",
                "인증 메일·비밀번호 재설정 메일은 Firebase 콘솔 템플릿을 사용합니다. 문구는 firebase_email_templates.txt 에 적어 두었습니다.",
            ],
            st,
        )
    )
    story.append(
        Callout(
            "초기 버전과의 차이",
            "wishlist-appversion1 은 “아무 이메일/비밀번호나 넣으면 된다”는 가짜 로그인이었습니다. "
            "지금 version2 는 실제 Firebase 계정입니다. 콘솔에 없는 이메일로는 들어가지 않습니다.",
            st,
            tint=HexColor("#EFE6DC"),
        )
    )

    # 4
    story.append(Spacer(1, 10))
    story.append(P("4. 역할 나누기 — 화면 / 상태 / 저장소", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(
        P(
            "코드를 세 층으로 보면 이해가 쉽습니다. 화면은 입력만 받고, 규칙은 AppStore가 정하고, "
            "Firebase 호출은 AccountRepository가 합니다.",
            st["body"],
        )
    )
    story.append(
        table(
            ["층", "위치", "책임"],
            [
                [
                    "화면",
                    "lib/screens/auth/… , mypage_screen.dart",
                    "입력 폼, 로딩, 사용자에게 보여줄 한국어 에러",
                ],
                [
                    "앱 상태",
                    "lib/data/app_store.dart",
                    "로그인 여부, 인증 대기, 세션 적재, 유효성 검사, 에러를 쉬운 말로 바꿈",
                ],
                [
                    "저장소",
                    "lib/services/account_repository.dart",
                    "Auth/Firestore/Storage API, 아이디 예약, 탈퇴 시 데이터 삭제",
                ],
                [
                    "라우팅",
                    "lib/main.dart 의 GoRouter redirect",
                    "로그인 전·인증 대기·환영 화면에 따라 강제 이동",
                ],
            ],
            st,
            [22 * mm, 52 * mm, W - 74 * mm],
        )
    )
    story.append(P("표 2. 로그인 코드의 층", st["caption"]))
    story.append(
        P(
            "핵심 상태 플래그는 세 가지입니다.",
            st["body"],
        )
    )
    story.extend(
        bullets(
            [
                "<b>isLoggedIn</b> — 이메일 인증까지 끝나고 Firestore 프로필을 읽은 상태. 이때만 홈으로 갑니다.",
                "<b>awaitingEmailVerification</b> — Auth 계정은 생겼지만 메일 링크를 아직 안 누른 상태. /verify-email 에 붙잡힙니다.",
                "<b>showSignupWelcome</b> — 방금 인증을 마친 직후 1.8초 환영 화면(/welcome).",
            ],
            st,
        )
    )

    # 5
    story.append(P("5. 사용자가 보는 화면과 이동 규칙", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(
        table(
            ["경로", "화면", "언제 보이나"],
            [
                ["/login", "LoginScreen", "로그아웃 상태. 같은 화면에서 회원가입으로 전환"],
                ["/verify-email", "EmailVerificationScreen", "가입 직후, 또는 미인증 계정으로 로그인했을 때"],
                ["/account-recovery", "AccountRecoveryScreen", "로그인 화면의 “이메일 / 비밀번호 찾기”"],
                ["/welcome", "SignupWelcomeScreen", "인증 직후 한 번. 자동으로 홈으로 이동"],
                ["/", "위시리스트 홈", "isLoggedIn == true"],
            ],
            st,
            [38 * mm, 48 * mm, W - 86 * mm],
        )
    )
    story.append(P("표 3. 인증 관련 경로", st["caption"]))
    story.append(P("redirect 규칙 (GoRouter)", st["h2"]))
    story.extend(
        bullets(
            [
                "인증 대기 중이면 어디를 눌러도 /verify-email 로 보냅니다.",
                "로그인되지 않았고 계정 찾기 화면도 아니면 /login 으로 보냅니다. 그래서 홈·마이페이지는 로그인 없이 열리지 않습니다.",
                "이미 로그인된 채 /login, /verify-email, /account-recovery, /welcome 에 있으면 홈(/)으로 보냅니다.",
                "앱을 다시 켜면 Firebase currentUser를 보고, 미인증이면 다시 인증 화면, 인증됐으면 프로필을 읽어 홈으로 갑니다.",
            ],
            st,
        )
    )

    # 6
    story.append(P("6. 회원가입", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(
        P(
            "로그인 화면에서 “계정이 없나요? 회원가입”을 누르면 이름·아이디 칸이 더 나옵니다. "
            "제출 시 AppStore.register() 가 아래 순서로 일합니다.",
            st["body"],
        )
    )
    story.append(
        step_row(
            ["입력 검사", "아이디 예약 확인", "초안 저장", "Auth 가입", "인증 화면"],
            [
                "이메일·비밀번호·아이디 필수. 비밀번호 6자 이상",
                "handles 와 users.handleLower 를 조회. 남이 쓰면 거절",
                "이름·아이디를 기기에 잠시 저장 (인증 전에 Firestore에 안 씀)",
                "createUserWithEmailAndPassword + 인증 메일 발송",
                "isLoggedIn은 false. /verify-email 로 이동",
            ],
            st,
            W,
        )
    )
    story.append(P("그림 1. 회원가입이 홈으로 바로 들어가지 않는 이유", st["caption"]))
    story.append(
        P(
            "중요합니다. <b>이 시점에는 Firestore 프로필이 아직 없습니다.</b> "
            "Auth에만 “이 이메일로 가입 중”인 사용자가 생깁니다. "
            "아이디를 지금 확정 예약하지 않는 이유는, 메일을 인증하지 않고 이탈한 사람이 "
            "아이디만 선점하는 일을 줄이기 위해서입니다. 대신 가입 직전에 "
            "<b>assertHandleAvailable</b>으로 한 번 검사하고, 인증이 끝난 뒤 "
            "<b>트랜잭션으로 handles 문서를 차지</b>합니다.",
            st["body"],
        )
    )
    story.append(P("아이디 정규화", st["h2"]))
    story.extend(
        bullets(
            [
                "앞뒤 공백 제거, 가운데 공백 제거.",
                "@ 가 없으면 앞에 @ 를 붙입니다. 사용자는 “mina”만 넣어도 @mina 가 됩니다.",
                "비교와 예약 키는 소문자입니다. @Mina 와 @mina 는 같은 아이디로 봅니다.",
            ],
            st,
        )
    )
    story.append(
        Callout(
            "가입 중 이름·아이디는 어디에 있나",
            "SharedPreferences 키 pending_register_name / pending_register_handle. "
            "인증 메일을 누르기 전에 앱을 꺼도, 다시 들어와 인증을 마치면 그 이름·아이디로 프로필을 만듭니다. "
            "인증을 취소(돌아가기)하면 이 초안과 Auth 세션을 지웁니다.",
            st,
        )
    )

    # 7
    story.append(P("7. 이메일 인증", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(
        P(
            "화면은 세 버튼입니다. “인증 완료했어요”, “인증 메일 다시 보내기”, “돌아가기”.",
            st["body"],
        )
    )
    story.append(
        table(
            ["버튼", "실제 동작"],
            [
                [
                    "인증 완료했어요",
                    "user.reload() 후 emailVerified 확인. 아직이면 안내. 됐으면 ensureProfile로 Firestore 계정을 만들고 환영 화면",
                ],
                [
                    "인증 메일 다시 보내기",
                    "Firebase sendEmailVerification(). 스팸함을 보라는 안내가 화면에 있음",
                ],
                [
                    "돌아가기",
                    "logout + 가입 초안 삭제. 로그인 화면으로. Auth 사용자 자체는 콘솔에 남을 수 있음(미인증 계정)",
                ],
            ],
            st,
            [42 * mm, W - 42 * mm],
        )
    )
    story.append(P("표 4. 이메일 인증 화면", st["caption"]))
    story.append(P("ensureProfile — 이때 진짜 앱 계정이 생긴다", st["h2"]))
    story.extend(
        bullets(
            [
                "emailVerified 가 false 이면 프로필을 만들지 않습니다.",
                "이미 users/{uid} 가 있으면 아이디 예약만 고치고 끝냅니다(재로그인).",
                "없으면 reclaimIdentityIfNeeded 로, 같은 이메일의 낡은 Firestore 잔여 문서를 치웁니다. (콘솔에서 Auth만 지운 경우 대비)",
                "트랜잭션으로 handles/{아이디소문자} 에 uid를 쓰고, users/{uid} 에 이름·이메일·아이디·아바타를 씁니다.",
                "기본 탭 “전체”만 만듭니다. 데모 카테고리는 넣지 않습니다.",
            ],
            st,
        )
    )
    story.append(
        P(
            "인증을 막 마치면 showSignupWelcome = true 가 되어 “회원가입을 축하합니다”가 약 1.8초 보인 뒤 위시리스트로 갑니다.",
            st["body"],
        )
    )

    # 8
    story.append(P("8. 로그인과 세션 복원", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(P("로그인 버튼", st["h2"]))
    story.extend(
        bullets(
            [
                "signInWithEmailAndPassword(email, password).",
                "reload 후 emailVerified 가 false 이면 홈으로 보내지 않고 인증 화면으로 보냅니다. (가입만 하고 메일을 안 누른 사람)",
                "인증된 사용자면 _hydrateSession: 프로필 보장 → 탭·상품·친구·알림·리뷰 로드.",
                "알림·받은 장바구니·리뷰를 읽을 때 규칙이 아직 안 맞으면 그 부분만 비우고 <b>로그인은 막지 않습니다.</b> 예전에 permission-denied 때문에 로그인 직후 튕기던 문제를 이렇게 막았습니다.",
            ],
            st,
        )
    )
    story.append(P("앱 재시작", st["h2"]))
    story.append(
        P(
            "main() 에서 Firebase.initializeApp 후 AppStore.init(). "
            "currentUser 가 있으면 같은 _hydrateSession을 탑니다. "
            "firebase_options.dart 의 apiKey 가 YOUR_ 로 시작하면 firebaseReady=false 이고 로그인 버튼이 사실상 동작하지 않으며, FIREBASE_SETUP 안내를 띄웁니다.",
            st["body"],
        )
    )

    # 9
    story.append(P("9. 이메일 찾기 · 비밀번호 찾기", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(
        P(
            "로그인 화면의 “이메일 / 비밀번호 찾기” → /account-recovery. "
            "한 화면에서 세그먼트로 두 기능을 고릅니다.",
            st["body"],
        )
    )
    story.append(P("비밀번호 찾기", st["h2"]))
    story.extend(
        bullets(
            [
                "가입 이메일을 입력하면 sendPasswordResetEmail.",
                "Firebase가 재설정 링크 메일을 보냅니다. 앱은 새 비밀번호를 직접 받지 않습니다.",
                "메일 제목/본문은 콘솔 템플릿 “wishkit 비밀번호 재설정”.",
            ],
            st,
        )
    )
    story.append(P("이메일 찾기", st["h2"]))
    story.extend(
        bullets(
            [
                "사용자는 비밀번호가 아니라 <b>아이디</b>를 기억할 때가 많습니다. 아이디로 가입 이메일을 알려줍니다.",
                "users 에서 handleLower == 입력값 인 문서를 1개 찾습니다.",
                "이메일은 그대로 보여주지 않습니다. k***m@gmail.com 처럼 가운데를 가립니다. (_maskEmail)",
                "프로필이 공개 읽기인 이유 중 하나가 바로 이 찾기 기능입니다. 비밀번호는 절대 내려주지 않습니다.",
            ],
            st,
        )
    )
    story.append(
        Callout(
            "왜 아이디로 이메일을 찾나",
            "아이디는 친구에게 보여주는 공개 이름표입니다. 이메일은 로그인 키입니다. "
            "아이디가 사람마다 유일해야, “@mina 로 가입한 메일”이 한 통으로 정해집니다. "
            "아이디가 겹치면 이메일 찾기가 누구 메일인지 알 수 없고, 아래 12장의 팔로우 문제도 생깁니다.",
            st,
            tint=HexColor("#E7EDE4"),
        )
    )

    # 10
    story.append(P("10. 비밀번호 변경 · 로그아웃", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(P("비밀번호 변경 (마이페이지 → 비밀번호 수정하기)", st["h2"]))
    story.extend(
        bullets(
            [
                "현재 비밀번호로 재인증(reauthenticate)한 뒤 updatePassword.",
                "새 비밀번호 6자 이상, 현재와 달라야 함.",
                "너무 오래전에 로그인한 세션이면 requires-recent-login → “다시 로그인한 뒤 변경해 주세요.”",
            ],
            st,
        )
    )
    story.append(P("로그아웃", st["h2"]))
    story.append(
        P(
            "Firebase signOut 후 앱 메모리를 게스트 상태로 비웁니다. "
            "위시리스트·친구 목록은 기기에 남아 보이지 않습니다. "
            "같은 계정으로 다시 로그인하면 Firestore에서 다시 불러옵니다.",
            st["body"],
        )
    )

    # 11
    story.append(P("11. 계정 탈퇴", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(
        P(
            "마이페이지 메뉴 → 탈퇴하기. 경고문(“되돌릴 수 없어요”)과 비밀번호 확인 후 진행합니다.",
            st["body"],
        )
    )
    story.append(
        step_row(
            ["재인증", "관계 끊기", "내 문서 삭제", "아이디 반납", "Auth 삭제"],
            [
                "비밀번호로 본인 확인",
                "내가 팔로우한 사람, 나를 팔로우한 사람의 카운트까지 정리",
                "tabs, products, following, followers, notifications, baskets, reviews",
                "handles/{아이디} 가 내 uid이면 삭제. 다른 사람이 그 아이디를 쓸 수 있게",
                "user.delete(). 이후 같은 이메일로 다시 가입 가능",
            ],
            st,
            W,
        )
    )
    story.append(P("그림 2. 탈퇴 순서 — Auth보다 Firestore를 먼저 지운다", st["caption"]))
    story.append(
        P(
            "순서가 중요합니다. Auth 사용자를 먼저 지우면, 그 다음 Firestore 삭제가 권한 거부될 수 있습니다. "
            "그래서 Firestore 트리와 handle 예약을 지운 뒤 마지막에 user.delete() 합니다. "
            "콘솔에서 Auth만 지워 버린 낡은 데이터는, 같은 이메일로 다시 가입할 때 reclaimIdentityIfNeeded 가 치웁니다.",
            st["body"],
        )
    )

    # 12 — the unique handle story the user cared about
    story.append(P("12. 아이디가 겹치면 안 되는 이유", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(
        P(
            "팔로우 저장 자체는 uid 로 합니다. "
            "users/{내uid}/following/{상대uid} 와 users/{상대uid}/followers/{내uid}. "
            "그런데 사람이 앱에서 친구를 고를 때는 uid가 아니라 <b>아이디와 이름</b>을 봅니다. "
            "디렉터리·검색·알림·이메일 찾기도 handle 로 사람을 찾습니다.",
            st["body"],
        )
    )
    story.append(P("겹치면 실제로 깨지는 것", st["h2"]))
    story.extend(
        bullets(
            [
                "<b>누구를 팔로우했는지 화면에서 구분이 안 됩니다.</b> 목록에 @mina 가 두 명이면, 버튼을 눌러도 기대한 사람이 아닐 수 있습니다.",
                "<b>이메일 찾기</b>는 handleLower 로 문서 1개만 가져옵니다. 겹치면 다른 사람 메일이 가려진 채로 나올 수 있습니다.",
                "<b>알림</b>에 fromHandle 이 붙습니다. 같은 아이디면 “누가 팔로우했는지” 알림이 거짓처럼 보입니다.",
                "<b>탈퇴 후 아이디 재사용</b>이 위험합니다. 예약을 안 풀면 탈퇴한 아이디를 아무도 못 쓰고, 예약을 풀었는데 프로필에 같은 handleLower 가 남아 있으면 산 사람과 죽은 문서가 섞입니다.",
                "친구 디렉터리는 users 컬렉션을 읽어 handle을 보여 줍니다. 유일하지 않으면 소셜 기능 전체가 “사람 = 아이디”라는 전제가 무너집니다.",
            ],
            st,
        )
    )
    story.append(P("그래서 한 일", st["h2"]))
    story.append(
        table(
            ["장치", "내용"],
            [
                [
                    "handles/{소문자아이디}",
                    "전역 예약 테이블. 문서 ID가 아이디, 필드 uid가 주인. 한 아이디에 문서 하나",
                ],
                [
                    "users.handleLower",
                    "프로필에도 소문자 아이디를 넣어 조회·이메일 찾기에 사용",
                ],
                [
                    "가입 직전 assertHandleAvailable",
                    "이미 살아있는 프로필이 쓰면 “이미 사용 중인 아이디예요”",
                ],
                [
                    "인증 후 트랜잭션 claim",
                    "동시에 같은 아이디를 치려는 두 가입을 한 명만 통과시킴",
                ],
                [
                    "프로필 수정",
                    "아이디를 바꾸면 새 키를 차지하고, 내 것이던 옛 키를 삭제",
                ],
                [
                    "탈퇴",
                    "내 uid가 적힌 handle 문서를 삭제해 아이디를 반납",
                ],
                [
                    "같은 이메일 재가입",
                    "콘솔에서 Auth만 지운 잔여는 회수. 다른 사람 아이디는 절대 뺏지 않음",
                ],
            ],
            st,
            [48 * mm, W - 48 * mm],
        )
    )
    story.append(P("표 5. 아이디 유일성을 지키는 장치", st["caption"]))
    story.append(
        P(
            "한 문장으로 말하면, <b>팔로우는 uid로 저장하지만 사람은 아이디로 찾는다.</b> "
            "아이디가 유일해야 팔로우·팔로잉·친구 위시리스트·살까말까 보내기가 같은 사람을 가리킵니다.",
            st["body"],
        )
    )

    # 13
    story.append(P("13. Firestore 데이터 구조", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(
        table(
            ["경로", "의미"],
            [
                ["users/{uid}", "프로필. email, name, handle, handleLower, followers, following, avatarUrl"],
                ["users/{uid}/tabs/{tabId}", "위시리스트 탭. 신규는 ‘전체’만"],
                ["users/{uid}/products/{productId}", "찜한 상품"],
                ["users/{uid}/following/{otherUid}", "내가 팔로우하는 사람"],
                ["users/{uid}/followers/{otherUid}", "나를 팔로우하는 사람"],
                ["users/{uid}/notifications/{id}", "팔로우·살까말까·리뷰 알림"],
                ["users/{uid}/receivedBaskets/{id}", "친구가 보낸 살까말까"],
                ["users/{uid}/sentBaskets/{id}", "내가 보낸 살까말까"],
                ["users/{uid}/reviews/{id}", "상품 리뷰"],
                ["handles/{handleLower}", "아이디 → uid 예약. 예: handles/@mina"],
            ],
            st,
            [58 * mm, W - 58 * mm],
        )
    )
    story.append(P("표 6. 계정과 소셜이 쓰는 Firestore 경로", st["caption"]))
    story.append(
        P(
            "Firebase 프로젝트 ID는 softstudio-wishlist-app 입니다. "
            "iOS 번들 ID는 com.softstudio.wishlist. "
            "설정 파일은 flutter_app/lib/firebase_options.dart 입니다.",
            st["body"],
        )
    )

    # 14
    story.append(P("14. 보안 규칙", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(
        P(
            "파일: wishlist-appversion2/firestore.rules . 배포는 firebase deploy --only firestore:rules . "
            "규칙을 안 올리면 알림·장바구니 공유는 실패할 수 있지만, 앱은 그 실패로 로그인을 막지 않습니다.",
            st["body"],
        )
    )
    story.extend(
        bullets(
            [
                "<b>users 읽기</b>는 누구나 가능. 친구 발견과 아이디로 이메일 찾기(가린 값)를 위해.",
                "<b>users 생성</b>은 본인 uid만. 인증된 사용자가 자기 프로필만 만듦.",
                "<b>팔로우 카운트</b>는 예외적으로 상대 문서의 followers/following 숫자만 ±1 할 수 있음. 이름·이메일은 못 바꿈.",
                "<b>handles</b> 생성은 자기 uid를 넣는 경우만. 수정/삭제는 주인, 또는 주인 프로필이 사라진 고아 문서, 또는 같은 이메일로 재가입한 사용자.",
                "탈퇴·재가입을 위해, 같은 이메일이면 낡은 하위 컬렉션을 지울 수 있게 해 두었습니다.",
            ],
            st,
        )
    )

    # 15
    story.append(P("15. 에러 메시지", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(
        P(
            "Firebase 코드는 영어입니다. 화면에서는 한국어로 바꿉니다.",
            st["body"],
        )
    )
    story.append(
        table(
            ["Firebase / 상황", "사용자에게 보이는 말"],
            [
                ["email-already-in-use", "이미 가입된 이메일이에요. 로그인으로 전환해 보세요."],
                ["invalid-email", "이메일 형식이 올바르지 않아요."],
                ["weak-password", "비밀번호가 너무 짧아요 (6자 이상)."],
                ["user-not-found / wrong-password / invalid-credential", "이메일 또는 비밀번호가 맞지 않아요."],
                ["network-request-failed", "네트워크 연결을 확인해 주세요."],
                ["too-many-requests", "요청이 너무 많아요. 잠시 후 다시 시도해 주세요."],
                ["아이디 중복", "이미 사용 중인 아이디예요."],
                ["requires-recent-login (탈퇴·비번변경)", "보안을 위해 다시 로그인한 뒤 진행해 주세요."],
            ],
            st,
            [70 * mm, W - 70 * mm],
        )
    )
    story.append(P("표 7. 자주 나오는 인증 오류", st["caption"]))

    # 16
    story.append(P("16. 주요 파일", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(
        table(
            ["파일", "역할"],
            [
                ["lib/main.dart", "Firebase 초기화, 로그인 강제 라우팅"],
                ["lib/firebase_options.dart", "프로젝트 키. YOUR_ 이면 미연결로 간주"],
                ["lib/data/app_store.dart", "register / login / 인증 / 탈퇴 / 세션"],
                ["lib/services/account_repository.dart", "Auth·Firestore·Storage·handle 유일성"],
                ["lib/screens/auth/login_screen.dart", "로그인·회원가입 폼"],
                ["lib/screens/auth/email_verification_screen.dart", "메일 인증"],
                ["lib/screens/auth/account_recovery_screen.dart", "이메일·비밀번호 찾기"],
                ["lib/screens/auth/signup_welcome_screen.dart", "가입 축하"],
                ["lib/screens/mypage/mypage_screen.dart", "비번 변경, 로그아웃, 탈퇴"],
                ["firestore.rules", "읽기/쓰기 권한, handles 예약 규칙"],
                ["firebase_email_templates.txt", "인증·재설정 메일 문구"],
            ],
            st,
            [62 * mm, W - 62 * mm],
        )
    )
    story.append(P("표 8. 로그인 관련 파일 지도", st["caption"]))

    # 17
    story.append(P("17. 아직 없는 것 · 운영 시 확인할 것", st["h1"]))
    story.append(HLine(ACCENT, 1.2))
    story.append(P("현재 없는 기능", st["h2"]))
    story.extend(
        bullets(
            [
                "구글 로그인, 애플 로그인, 카카오 로그인. (카카오는 살까말까 <b>공유</b>용 SDK만 연결)",
                "전화번호 로그인, 익명 로그인.",
                "이메일 찾기에서 전체 이메일 표시. 항상 마스킹합니다.",
            ],
            st,
        )
    )
    story.append(P("배포·콘솔에서 확인할 것", st["h2"]))
    story.extend(
        bullets(
            [
                "Authentication → Sign-in method 에서 Email/Password 사용 설정.",
                "Authentication → Templates 에 인증 메일·비밀번호 재설정 문구 반영.",
                "firestore.rules 최신본 배포. 안 올리면 알림·살까말까 권한이 거부될 수 있음.",
                "Storage 규칙도 아바타·리뷰 사진 업로드에 필요.",
                "콘솔에서 사용자만 지우면 Firestore 잔여가 남을 수 있음. 앱 탈퇴 기능을 쓰는 편이 안전합니다.",
            ],
            st,
        )
    )
    story.append(Spacer(1, 8))
    story.append(
        Callout(
            "기억할 문장 세 개",
            "1) 자격 증명은 Auth, 사람 정보는 Firestore, 파일은 Storage.<br/>"
            "2) 메일 인증 전에는 앱 계정이 없고, 인증 후에 아이디를 예약한다.<br/>"
            "3) 아이디는 전역에서 하나. 겹치면 팔로우와 계정 찾기가 사람을 구분하지 못한다.",
            st,
            tint=HexColor("#E7EDE4"),
        )
    )
    story.append(Spacer(1, 14))
    story.append(HLine(LINE, 0.6))
    story.append(
        P(
            "이 문서는 2026-08-14 기준 wishlist-appversion2 Flutter 앱 코드와 일치합니다. "
            "소셜 로그인을 붙이거나 아이디 규칙을 바꾸면 이 설명서도 함께 고치면 됩니다.",
            st["small"],
        )
    )

    def first_page(canvas, doc_):
        canvas.saveState()
        w, h = A4
        canvas.setFillColor(CANVAS)
        canvas.rect(0, 0, w, h, fill=1, stroke=0)
        canvas.restoreState()

    doc.build(story, onFirstPage=first_page, onLaterPages=add_header_footer)
    print(out)


if __name__ == "__main__":
    build()
