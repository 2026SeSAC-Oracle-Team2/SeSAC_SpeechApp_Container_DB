-- ============================================================
-- 05_session_voice_schema_ddl.sql
-- 스키마: SPEECHAPP_USER
-- 테이블: CONTENT_TYPE, LEARNING_SESSION, TURN, TURN_IMAGE, VOICE_RECORD
-- v1.9 (2026-09-01): P3-23 renamed SESSION → learning_session, added sequences
-- v1.95 (2026-09-02): TURN 테이블에 score 컬럼 추가
-- v2.0 (2026-09-04, D-1 / 04_Database_Design.md v2.1+v2.3+v2.6):
--   LEARNING_SESSION 3컬럼 ADD: type(today/theme) / session_name /
--     report_viewed_at + chk_session_type CHECK
--   CONTENT_TYPE seed 5종 → 6종: LISTEN 폐지 → LISTEN_TEXT/LISTEN_PICTURE
--   TURN CHECK 재생성: chk_turn_content_type 6종 / chk_turn_listen 세분화 /
--     chk_turn_naming 유지
--   LEARNING_SESSION AQ+피드백 6컬럼 / TURN.status (v1.97 = LIVE 기준 반영)
--   VOICE_RECORD rename(SPEAKING_TIME/ARTICULATION_TIME, ADR-010) + IDENTITY
--     (v1.97 = LIVE 기준 반영)
-- ============================================================

ALTER SESSION SET CONTAINER = XEPDB1;

-- -----------------------------------------------------------
-- CONTENT_TYPE (자연키 PK)
-- -----------------------------------------------------------
CREATE TABLE speechapp_user.content_type (
    type_code   VARCHAR2(20) PRIMARY KEY,
    type_name   VARCHAR2(50) NOT NULL,
    category    VARCHAR2(50),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------
-- LEARNING_SESSION (renamed from SESSION due to Oracle reserved word)
-- v1.3 기획: type=today(오늘의 학습)/theme(테마별 학습) — 컨테이너
--   엔드포인트 분기(/sessions/today vs theme)와 매핑
-- session_name: 학습 기록 카드 표시명 —
--   today=`오늘의 학습 - {테마명}` / theme=시나리오명(컨텐츠 팀 확정분)
-- report_viewed_at: 상세 보고서 조회 시각 — null=미조회(알림함 판별)
-- status: IN_PROGRESS/COMPLETED/COMPLETED_NO_TALK(이야기 없이 조기종료)
-- aq: 세션 총점(8문제만, /report/problems 시점 적재)
-- ============================================================
CREATE TABLE speechapp_user.learning_session (
    id          NUMBER(19) PRIMARY KEY,
    user_id     NUMBER(19) NOT NULL,
    theme       VARCHAR2(30),
    type        VARCHAR2(20),
    session_name VARCHAR2(100),
    status      VARCHAR2(20) DEFAULT 'IN_PROGRESS',
    report_viewed_at TIMESTAMP,
    aq          NUMBER(3),
    listen_feedback      CLOB,
    naming_feedback      CLOB,
    shadowing_feedback   CLOB,
    self_talk_feedback   CLOB,
    talk_feedback        CLOB,
    total_feedback       CLOB,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP,

    CONSTRAINT fk_session_user_id
        FOREIGN KEY (user_id) REFERENCES speechapp_user.app_user(id),
    -- 세션 종류: today / theme
    CONSTRAINT chk_session_type
        CHECK (type IN ('today','theme')),
    -- 세션 총점 AQ (100점 만점 정수, 리포트 생성 시점 적재 — 전까지 NULL)
    CONSTRAINT chk_learning_session_aq
        CHECK (aq BETWEEN 0 AND 100)
);

CREATE INDEX idx_session_user_id ON speechapp_user.learning_session(user_id);

-- -----------------------------------------------------------
-- SEQUENCES for ID generation
-- -----------------------------------------------------------
CREATE SEQUENCE speechapp_user.session_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE speechapp_user.turn_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE speechapp_user.voice_record_seq START WITH 1 INCREMENT BY 1;

-- -----------------------------------------------------------
-- TURN
-- v2.3: content_type 6종 — LISTEN 폐지(LISTEN_TEXT/LISTEN_PICTURE 분화)
-- choices_json 유형별 고정: LISTEN_TEXT=TEXT만 / LISTEN_PICTURE=IMAGE만
-- ============================================================
CREATE TABLE speechapp_user.turn (
    id              NUMBER(19) PRIMARY KEY,
    session_id      NUMBER(19) NOT NULL,
    turn_number     NUMBER(5) NOT NULL,
    content_type    VARCHAR2(20) NOT NULL,
    status          VARCHAR2(20) DEFAULT 'PENDING' NOT NULL,
    prompt_text     CLOB,
    choices_json    CLOB,
    correct_value   VARCHAR2(255),
    selected_value  VARCHAR2(255),
    answer_text     CLOB,
    hints_shown     NUMBER(1),
    score           NUMBER(5,2),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_turn_session_id
        FOREIGN KEY (session_id) REFERENCES speechapp_user.learning_session(id),
    CONSTRAINT fk_turn_content_type
        FOREIGN KEY (content_type) REFERENCES speechapp_user.content_type(type_code),

    -- content_type must be one of the 6 seeded types (v2.3: LISTEN 세분화)
    CONSTRAINT chk_turn_content_type
        CHECK (content_type IN ('LISTEN_TEXT','LISTEN_PICTURE','NAMING','SHADOWING','SELF_TALK','STORYTELLING')),

    -- TURN.status (ADR-007): PENDING(출제·미풀이) / SUBMITTED(답안 제출) / SCORED(채점 완료)
    CONSTRAINT chk_turn_status
        CHECK (status IN ('PENDING','SUBMITTED','SCORED')),

    -- LISTEN_TEXT/LISTEN_PICTURE: choices_json and correct_value are required
    CONSTRAINT chk_turn_listen
        CHECK (
            (content_type NOT IN ('LISTEN_TEXT','LISTEN_PICTURE'))
            OR (choices_json IS NOT NULL AND correct_value IS NOT NULL)
        ),

    -- NAMING: correct_value is required
    CONSTRAINT chk_turn_naming
        CHECK (
            (content_type != 'NAMING')
            OR (correct_value IS NOT NULL)
        )
);

CREATE INDEX idx_turn_session_turn_number ON speechapp_user.turn(session_id, turn_number);

-- -----------------------------------------------------------
-- TURN_IMAGE
-- Cross-schema FK: image_id -> SPEECHAPP_CONTENT.IMAGE_RESOURCE
-- -----------------------------------------------------------
CREATE TABLE speechapp_user.turn_image (
    turn_id      NUMBER(19) NOT NULL,
    image_id     NUMBER(19) NOT NULL,
    image_order  NUMBER(2) NOT NULL,

    PRIMARY KEY (turn_id, image_id),

    CONSTRAINT fk_turn_image_turn_id
        FOREIGN KEY (turn_id) REFERENCES speechapp_user.turn(id),
    CONSTRAINT fk_turn_image_image_id
        FOREIGN KEY (image_id) REFERENCES speechapp_content.image_resource(image_id),

    CONSTRAINT uq_turn_image_order
        UNIQUE (turn_id, image_order)
);

-- -----------------------------------------------------------
-- VOICE_RECORD
-- 발화지표 rename (ADR-010): speaking_time(구 response_time) /
--   articulation_time(구 articulation_rate)
-- ============================================================
CREATE TABLE speechapp_user.voice_record (
    id                NUMBER(19) GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    user_id           NUMBER(19) NOT NULL,
    session_id        NUMBER(19) NOT NULL,
    turn_id           NUMBER(19) NOT NULL,
    speaker           VARCHAR2(10) NOT NULL,
    voice_file_path   VARCHAR2(500) NOT NULL,
    duration_seconds  NUMBER(5),
    syllables         NUMBER,
    speaking_time     NUMBER,
    articulation_time NUMBER,
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_voice_record_user_id
        FOREIGN KEY (user_id) REFERENCES speechapp_user.app_user(id),
    CONSTRAINT fk_voice_record_session_id
        FOREIGN KEY (session_id) REFERENCES speechapp_user.learning_session(id),
    CONSTRAINT fk_voice_record_turn_id
        FOREIGN KEY (turn_id) REFERENCES speechapp_user.turn(id),

    CONSTRAINT chk_voice_record_speaker
        CHECK (speaker IN ('USER','AI')),

    -- Only one record per (turn_id, speaker)
    CONSTRAINT uq_voice_record_turn_speaker
        UNIQUE (turn_id, speaker),

    -- AI speaker: 발화지표 3종 must be NULL (ADR-010 rename 반영)
    CONSTRAINT chk_voice_record_ai
        CHECK (
            speaker != 'AI'
            OR (syllables IS NULL AND speaking_time IS NULL AND articulation_time IS NULL)
        )
);

CREATE INDEX idx_voice_record_session_id ON speechapp_user.voice_record(session_id);
CREATE INDEX idx_voice_record_turn_id ON speechapp_user.voice_record(turn_id);

-- -----------------------------------------------------------
-- SEED DATA: CONTENT_TYPE 6종 (v2.3 LISTEN 세분화)
-- LISTEN_TEXT/LISTEN_PICTURE는 지표상 동일 LISTEN (운영 구분용 —
-- 채점 방식 동일, 백엔드 자체 100/0)
-- ============================================================
INSERT INTO speechapp_user.content_type (type_code, type_name, category) VALUES
('LISTEN_TEXT',    '듣기(텍스트)',  'receptive');
INSERT INTO speechapp_user.content_type (type_code, type_name, category) VALUES
('LISTEN_PICTURE', '듣기(그림)',    'receptive');
INSERT INTO speechapp_user.content_type (type_code, type_name, category) VALUES
('NAMING',         '이름 맞추기',   'productive');
INSERT INTO speechapp_user.content_type (type_code, type_name, category) VALUES
('SHADOWING',      '쉐도잉',        'productive');
INSERT INTO speechapp_user.content_type (type_code, type_name, category) VALUES
('SELF_TALK',      '자기 대화',     'productive');
INSERT INTO speechapp_user.content_type (type_code, type_name, category) VALUES
('STORYTELLING',   '스토리텔링',    'productive');

COMMIT;