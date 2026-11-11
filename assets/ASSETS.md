# 자산 출처 — 모든 자산은 여기 있어야 한다

> 정정 이력: 2026-11-10 — 첫 작성(C1-0). 2026-11-10(C2) — 인물 도트 묶음 `chars/` 세 줄(취호전 시트 내보내기 · 보류 #2 답). 2026-11-11 — 도트를 그만 쓰고(사용자 지시 · `docs/기획_차이.md` (라)12) 벡터 초상 두 줄(`chars/looks.json` · `chars/svg/*.svg`)과 글꼴 Noto Sans KR 로 바꿨다. 옛 도트 묶음 · Galmuri11 은 지웠다(git 이력에 있음).

`scripts/verify.py` '자산 출처' 단계가 `assets/` 의 파일(`.import` 빼고)과 아래 표 첫 칸을 대조한다(CLAUDE.md 13절). 원작 컷 · 원작 그림을 쓴 자산은 아직 없다 — 생기면 원작 위치(`화/컷`)를 적고, 배포 빌드에서는 기본으로 뺀다.

| 파일 | 출처 | 쓰는 곳 |
|---|---|---|
| `fonts/NotoSansKR-wght.ttf` | 외부 — Noto Sans KR(가변 굵기 100~900 · Adobe · Google · SIL Open Font License 1.1) · 작업 서버 사용자 글꼴에서 부분집합으로 줄임(2026-11-11 · fontTools `pyftsubset` · 라틴 · 기호 · 한글 음절 전부 · 판 데이터에 쓰인 글자 · 힌팅 뺌 · 10.4MB → 4.4MB) | 모든 글 — `ui/theme.tres` 글꼴(본문 500 · 단추 700 · 제목 850) |
| `fonts/OFL-NotoSansKR.txt` | 외부 — 위 글꼴의 저작권 줄 + OFL 1.1 전문(글꼴과 함께 배포한다) | 글꼴 라이선스 |
| `icon.svg` | 직접 — 밤 바탕 · 흰 성벽 · 붉은 점(원작 그림 아님 · 2026-11-10) | 앱 아이콘 — `project.godot` `config/icon` |
| `chars/looks.json` | 직접 — 인물 136명의 외형 표(성별 · 머리 모양 · 머리/피부/옷 색 · 안경 · 수염 · 흉터 · 차림). 처음 값은 2026-11-11 한 번 뽑음: 색은 옛 도트 초상(취호전 `tools/export_characters.py` 결과 · 취호전 커밋 b5c8991)에서, 모양 낱말은 canon `look.text` 에서(원작 컷은 읽지 않음). 손으로 고쳐도 된다 | `scripts/draw_portraits.py` 의 원본 |
| `chars/svg/*.svg` | 직접 — `scripts/draw_portraits.py` 가 `chars/looks.json` 에서 코드로 그린 벡터 초상(3/4 흉상 · 셀 음영 · 굵기가 변하는 잉크 선 · 배경 투명 · 384px · 밉맵 — 2026-11-11 2차). 원작 그림 · 다른 게임 그림 아님 | 간부 카드 · 지도 얼굴 패 · 구역 카드 · 조직 탭 · 전투 화면 — `ui/sprites.gd` |
