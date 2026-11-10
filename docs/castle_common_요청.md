# castle_common 요청 — castle_strategy(캐슬 제패) → castle_common

> 정정 이력: 2026-11-10 — 첫 작성(C0). castle_common `98ac39cc` 를 읽기만 해서 기계로 점검했다. 대상은 기획서 08 15절의 받을 데이터와 장르 팩 `packs/strategy/` 다.

- **넘기는 법**: 이 파일의 경로(`castle_strategy/docs/castle_common_요청.md`)를 castle_common 세션에 알려 준다. 같은 PC 면 경로만으로 된다. castle_common 이 반영하면 그 줄을 지우고, 번호는 다시 쓰지 않는다.
- **순서**(캐슬 규격 3절):
  - 원작 위치가 있는 줄을 먼저, 화 → 컷 오름차순으로 둔다(1부 `p1:` 를 먼저).
  - 위치가 없는 줄(데이터 칸 · 규격)은 그 뒤에 `파일:id` 순으로 둔다.
- 2층 값(등급 · 능력치)은 '바랄 값'에 후보만 적는다. 확정은 사용자가 한다.
- **급함**:
  - **막힘** — 판이 멈춘다.
  - **다음 마일스톤**
  - **언젠가**
- 지금 막힘은 **#14 하나**다. `games.json` 등록이 있어야 sync 로 받고, C1 본체를 시작할 수 있다.

| # | 위치 | 파일:id | 칸 | 지금 값 | 바랄 값 | 근거 | 급함 |
|---|---|---|---|---|---|---|---|
| 1 | `p1:021/028-054` | `packs/strategy/events.json:A:iseul` | `when.alive` · A 명단 | `iseul` 이 A 명단(`scenarios.json:A` roster 14)에 없다 | A 명단에 `iseul` 을 넣거나, 사건 앞에 등장(`join`) 결과를 넣는다 | 조건 인물이 판에 없어 일기토 사건이 일어나지 않는다(기계 점검) | 다음 마일스톤(C3 — A 완주) |
| 2 | `p1:023/006-009` | `packs/strategy/events.json:A:yundeoksu_death` | `when.alive` · A 명단 | `gangchangseok` 이 A 명단에 없다 | A 명단에 넣거나 조건을 고친다 | 같은 까닭 — A 의 26턴째 끝 사건이다 | 다음 마일스톤(C3) |
| 3 | `p1:070/005-021` | `packs/strategy/events.json:B:gustav` | `duel.fight` · B 명단 | `null` · `gustav` 이 B 명단에 없다 | 후보 `fight:p1_kimshin_gustav`(1부 모의전 `p1:071-074`) · B 명단에 `gustav` | canon 대결에 이 쌍이 있다. 일기토 연출에 대결 id 가 필요하다(08 4-2) | 다음 마일스톤(C5) |
| 4 | `p1:076/007-013` | `packs/strategy/events.json:B:honam` | `when.alive` · B 명단 | `yeominsu` 가 B 명단에 없다 | B 명단에 넣거나 조건을 고친다 | 조건 인물이 판에 없다 | 다음 마일스톤(C5) |
| 5 | `p1:090/004-007` | `packs/strategy/events.json:C:komodo` | `duel.fight` | `null` | 후보 `fight:jintae_komodo` | canon 대결에 이 쌍이 하나뿐이다 | 언젠가(C6) |
| 6 | `p1:095/182-198` | `packs/strategy/events.json:C:baekdochan` | `duel.fight` | `null` | 후보 `fight:kimshin_baekdochan` | canon 대결에 이 쌍이 있다(`fight:iskra_scale` 은 난전) | 언젠가(C6) |
| 7 | `p1:097/180-189` | `packs/strategy/events.json:C:namgunghyuk` | `duel.fight` | `null` | 후보 `fight:woojin_namgunghyuk`(확인 필요 — `fight:namgunghyuk` 은 2장 하성 본사 쪽) | canon 대결에 이 쌍이 있다 | 언젠가(C6) |
| 8 | `037/000-069` | `packs/strategy/events.json:D:yuwoosung` | `duel.fight` | `null` | 후보 `fight:jintae_seojae`(확인 필요 — 그 밖에 `fight:hwajinhotel` · `fight:jintae_sacheonwang`) | canon 대결에 이 쌍이 셋 있다 | 언젠가(C6) |
| 9 | `038/094-175` | `packs/strategy/events.json:D:douchen` | `duel.fight` | `null` | 후보 `fight:woojin_douchen` | canon 대결에 이 쌍이 있다 | 언젠가(C6) |
| 10 | `040/094-096` | `packs/strategy/events.json:D:richeon` | `duel.fight` | `null` | 후보 `fight:kimshin_richeon` | canon 대결에 이 쌍이 하나뿐이다 | 언젠가(C6) |
| 11 | `070/048-054` | `packs/strategy/events.json:E:jackson` | `when.alive` · E 명단 | `jackson` 이 E 명단에 없다 | E 명단에 넣거나 조건을 고친다 | 조건 인물이 판에 없다 | 언젠가(C6) |
| 12 | `109/042@0` | `packs/strategy/events.json:E:wanggiryong` | `when.alive` · E 명단 | `wanggiryong` 이 E 명단에 없다 | E 명단에 넣거나 조건을 고친다 | 조건 인물이 판에 없다 | 언젠가(C6) |
| 13 | `120/064@1411` | `packs/strategy/events.json:E:jintae_death` | `duel.fight` | `null` | 대결 id(이 쌍이 같이 든 canon 대결은 `fight:kimshin_mahakyoung` 하나 — 확인 필요) 또는 새 대결 | 서진태 사망 장면을 일기토로 연출하려면 대결 id 가 필요하다 | 언젠가(C6) |
| 14 | - | `games.json:castle_strategy` | 새 판 등록 | (없음) | 아래 '등록 내용' | 받기(sync)를 하려면 먼저 등록해야 한다(00 5-2 · 08 15절). 사용자 확인: 2026-11-10 판 id `castle_strategy` | **막힘** |
| 15 | - | `cases/rules_cases.json` | `one_shot` 줄 | 15줄 — 공격 쪽이 모두 내성 중위 | 공격 등급을 고루(톱 · 외성 · 전국구 …) 더한다 | 08 은 습격 난전에서 `one_shot` 을 많이 쓴다(14-2 쓸어 내기) | 언젠가(C3 전) |
| 16 | - | `data/characters.json:baekdochan` | `속도` · `힘` · `맷집` | 기술만 있다 | 사용자 확정 값. 없으면 08 14-2 · 14-3 의 '값 없는 인물' 규칙으로 계산한다 | 08 일기토 속도 순서에 `속도` 가 필요하다. 08 은 값이 없을 때의 대체값을 정하지 않았다 | 다음 마일스톤(C3) |
| 17 | - | `data/ranks.json:below` | '그 아래급' | 사다리 15 밖이라 `rank_index` 가 오류를 낸다 | 사다리 안 등급으로 대응시킬지(예: 건달급) 정해 둔다 | 명단 · 강함표에 '그 아래급'이 나오면 판이 계산할 수 없다 | 다음 마일스톤(C3) |
| 18 | - | `docs/개발규격/캐슬_게임공통.md` 4절 | 판별 메모 표 | castle_strategy 줄이 없다 | `castle_strategy` · Godot 4.7.2-stable · `data/` · `cases/` · `canon/` · `packs/strategy/` · 개발 규격 · Android 전용 | 새 판 | 언젠가 |
| 19 | - | `docs/기획서/00_공통_세계관과_데이터.md` 0절 | 08 줄 '저장소' | 제안 id `castle_conquest` | `castle_strategy`(사용자 2026-11-10) | 판 id 확정 | 언젠가 |
| 20 | - | `docs/기획서/08_캐슬제패_조직경영전략.md` | 0절 '판' · 15 · 18 · 19절 | 제안 id `castle_conquest` | `castle_strategy` | 판 id 확정 | 언젠가 |
| 21 | - | `docs/기획서/08_캐슬제패_조직경영전략.md` 1-1 | '정예' 칸 | 사람(최달천 · 김신 …) | 정예 = 단위(`factions.json` `elite`), 사람 = `aces` 로 칸 이름을 맞춘다 | 데이터와 문서가 다르다 | 언젠가 |
| 22 | - | `docs/기획서/08_캐슬제패_조직경영전략.md` 12절 | 예시 | `seoul_gangnam` · B 의 `baekui` · `hq: yeongdeungpo` · `events_done: ["beat:yundeoksu"]` | 있는 id(`hotelcastle` 등) · B 는 `bujinpa`(hq `bujindong`) · `events_done` 은 팩 사건 id(`A:yundeoksu`)와 진행 사건(`beat:`)을 나눈다는 설명 | 구현이 예시를 따라가면 틀린다 | 언젠가 |
| 23 | - | `packs/strategy/README.md` | '받는 판' 줄 | 제안 id `castle_conquest` | `castle_strategy` | 판 id 확정 | 언젠가 |
| 24 | - | `packs/strategy/characters.json` | `stats`(5능력치) | A 명단 중 `gangmanjae` · `gunter` · `kimhyeokju`, B 는 더해 `gusanghun`, P 는 8명(`gangminseong` · `gwonsuchan` · `pyoseong` · `gwakjungheon` · `wigilseong` · `baekganghoe` · `ssanggae` · `jeongpilseong`)에 없다 | AI 후보 → 사용자 확정 | 간부 행동 · 공작 성공률에 계산 · 수완 · 의리가 필요하다(08 14-1 · 14-4) | 다음 마일스톤(C1 본체 — A 3명) |
| 25 | - | `packs/strategy/scenarios.json:A` | `roster[].rank` | null 10/14: `chasumin` · `icheolmin` · `kimseongjun` · `kimjaehoon` · `kimseongyu` · `risa` · `gangmanjae` · `gunter` · `kimhyeokju` · `kimshin` | `kimshin` 은 `data/characters.json` 처음 등급(내성 중위) + `progression` 으로 채운다. 나머지 9명은 판독 기록으로 만든 후보를 사용자가 확정한다. 비전투 인물(정치 · 중개)은 '전투 안 함' 표시도 된다 | 간부 대우비(08 14-1 등급 번호 × 3) · 습격 · 일기토(14-2 · 14-3)가 등급으로 계산된다. 그 전엔 판이 provisional 자리값으로 둔다 | 다음 마일스톤(C1 본체) |
| 26 | - | `packs/strategy/scenarios.json:B` | `roster` · `roster[].rank` | null 22/44(`kimshin` 포함). 기둥 간부가 빠졌다 — castle_holdings · castle_hotel · gold · mori 는 두목만 있다(`aces`: mahakyoung · choedalcheon · odohwa · hide …) | 기둥마다 `aces` 와 행동대장급을 명단에 넣는다. 등급은 후보 → 사용자 확정 | 08 3-3 '간부 = 행동력' — 두목 하나뿐인 기둥은 할 수 있는 일이 없다 | 다음 마일스톤(C5) |
| 27 | - | `packs/strategy/scenarios.json:C` · `D` · `E` · `P` | `roster[].rank` | null — C 37/76 · D 57/109 · E 57/104 · P 9/13 | #25 와 같은 방식 | 같은 까닭 | 언젠가(C6) |
| 28 | - | `packs/strategy/scenarios.json:F` | `roster` · `zones` | 비어 있다(0) | IF '기둥들의 시대' 명단(1 · 2부 인물 전원 생존 — 08 7절)을 만드는 법을 정한다 | 시나리오 F 를 시작할 수 없다 | 언젠가(C6) |

## #14 등록 내용 (castle_common `games.json` `games[]` 에 더할 줄 — 허용 칸만)
```json
{
  "id": "castle_strategy",
  "name": "캐슬 제패(가칭) — 조직 경영 전략",
  "engine": "godot-4",
  "status": "active",
  "receives": ["data/*.json", "cases/*.json", "canon/*.json", "packs/strategy/*.json", "docs/개발규격/*.md"],
  "dest": "castle_strategy/data/common",
  "follows": ["rules/등급과_게이지.md", "rules/기술.md", "docs/개발규격/캐슬_게임공통.md", "docs/개발규격/게임개발규격.md"],
  "platforms": ["android"],
  "note": "2026-11-10 사용자 — 기획서 08 의 새 판(제안 id castle_conquest → castle_strategy). Godot 4.7.2-stable · 세로. canon/episodes(대사 원문 · 9.8MB)는 원작 사건 컷인(C6) 때 더한다. 쳐내기(rules/전투_쳐내기.md)는 실시간 규칙이라 따르지 않고 일기토 카드 '쳐내기'(can_parry)로 해석한다 — castle_tactics 와 같다"
}
```
- 받는 곳: base = castle_common 의 상위 폴더 → `castle_strategy/data/common/`. 받은 뒤 이 판의 `scripts/verify.py` 가 `SOURCE.json` sha256 을 검사한다.
- 받은 뒤 이 판에서 할 일: cases 3005줄을 `sim/rules_common.gd` 로 1e-9 안에서 맞춘다(C1 본체). README '반영 현황' 갱신 거리는 그때 목록으로 넘긴다.
