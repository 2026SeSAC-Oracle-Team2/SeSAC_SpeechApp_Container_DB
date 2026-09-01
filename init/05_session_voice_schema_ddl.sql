-- ============================================================
-- 05_session_voice_schema_ddl.sql
-- 스키마: SPEECHAPP_USER
-- 테이블: CONTENT_TYPE, LEARNING_SESSION, TURN, TURN_IMAGE, VOICE_RECORD
-- v1.9 (2026-09-01): P3-23 renamed SESSION → learning_session, added sequences
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
-- -----------------------------------------------------------
CREATE TABLE speechapp_user.learning_session (
    id          NUMBER(19) PRIMARY KEY,
    user_id     NUMBER(19) NOT NULL,
    theme       VARCHAR2(30),
    status      VARCHAR2(20) DEFAULT 'IN_PROGRESS',
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP,

    CONSTRAINT fk_session_user_id
        FOREIGN KEY (user_id) REFERENCES speechapp_user.app_user(id)
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
-- -----------------------------------------------------------
CREATE TABLE speechapp_user.turn (
    id              NUMBER(19) PRIMARY KEY,
    session_id      NUMBER(19) NOT NULL,
    turn_number     NUMBER(5) NOT NULL,
    content_type    VARCHAR2(20) NOT NULL,
    prompt_text     CLOB,
    choices_json    CLOB,
    correct_value   VARCHAR2(255),
    selected_value  VARCHAR2(255),
    answer_text     CLOB,
    hints_shown     NUMBER(1),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_turn_session_id
        FOREIGN KEY (session_id) REFERENCES speechapp_user.learning_session(id),
    CONSTRAINT fk_turn_content_type
        FOREIGN KEY (content_type) REFERENCES speechapp_user.content_type(type_code),

    -- content_type must be one of the 5 seeded types
    CONSTRAINT chk_turn_content_type
        CHECK (content_type IN ('LISTEN','NAMING','SHADOWING','SELF_TALK','STORYTELLING')),

    -- LISTEN: choices_json and correct_value are required
    CONSTRAINT chk_turn_listen
        CHECK (
            (content_type != 'LISTEN')
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
-- TODO: response_time unit not yet decided (nullable)
-- TODO: LISTEN selected_value representation may need refinement (nullable)
-- TODO: image-related type details pending (nullable)
-- -----------------------------------------------------------
CREATE TABLE speechapp_user.voice_record (
    id                NUMBER(19) PRIMARY KEY,
    user_id           NUMBER(19) NOT NULL,
    session_id        NUMBER(19) NOT NULL,
    turn_id           NUMBER(19) NOT NULL,
    speaker           VARCHAR2(10) NOT NULL,
    voice_file_path   VARCHAR2(500) NOT NULL,
    duration_seconds  NUMBER(5),
    syllables         NUMBER,
    response_time     NUMBER,
    articulation_rate NUMBER,
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

    -- AI speaker: syllables, response_time, articulation_rate must be NULL
    CONSTRAINT chk_voice_record_ai
        CHECK (
            speaker != 'AI'
            OR (syllables IS NULL AND response_time IS NULL AND articulation_rate IS NULL)
        )
);

CREATE INDEX idx_voice_record_session_id ON speechapp_user.voice_record(session_id);
CREATE INDEX idx_voice_record_turn_id ON speechapp_user.voice_record(turn_id);

-- -----------------------------------------------------------
-- SEED DATA: CONTENT_TYPE
-- -----------------------------------------------------------
INSERT INTO speechapp_user.content_type (type_code, type_name, category) VALUES
('LISTEN',       '듣기',         'receptive');
INSERT INTO speechapp_user.content_type (type_code, type_name, category) VALUES
('NAMING',       '이름 맞추기',   'productive');
INSERT INTO speechapp_user.content_type (type_code, type_name, category) VALUES
('SHADOWING',    '쉐도잉',       'productive');
INSERT INTO speechapp_user.content_type (type_code, type_name, category) VALUES
('SELF_TALK',    '자기 대화',    'productive');
INSERT INTO speechapp_user.content_type (type_code, type_name, category) VALUES
('STORYTELLING', '스토리텔링',   'productive');
