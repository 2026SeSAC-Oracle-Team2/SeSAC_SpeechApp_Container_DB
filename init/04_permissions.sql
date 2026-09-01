-- ============================================================
-- 04_permissions.sql
-- DB 사용자 계정 권한 부여
-- 실행 시점: 테이블 생성(02, 03, 05) 완료 후
-- ============================================================

-- -----------------------------------------------------------
-- 기본 연결 권한 (모든 계정)
-- -----------------------------------------------------------
GRANT CREATE SESSION TO speechapp_user;
GRANT CREATE SESSION TO speechapp_content;
GRANT CREATE SESSION TO speechapp_app;
GRANT CREATE SESSION TO speechapp_admin;

-- -----------------------------------------------------------
-- 스키마 소유자: 객체 생성 권한
-- -----------------------------------------------------------
GRANT CREATE TABLE    TO speechapp_user;
GRANT CREATE TABLE    TO speechapp_content;
GRANT CREATE SEQUENCE TO speechapp_user;
GRANT CREATE SEQUENCE TO speechapp_content;
GRANT CREATE TRIGGER  TO speechapp_user;
GRANT CREATE TRIGGER  TO speechapp_content;

-- -----------------------------------------------------------
-- app user: SPEECHAPP_USER 읽기/쓰기, SPEECHAPP_CONTENT 읽기 전용
-- -----------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON speechapp_user.app_user       TO speechapp_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON speechapp_user.user_profile  TO speechapp_app;

GRANT SELECT ON speechapp_content.image_resource TO speechapp_app;

-- -----------------------------------------------------------
-- app user: 신규 session/voice 테이블 읽기/쓰기 (P3-20)
-- -----------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON speechapp_user.content_type   TO speechapp_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON speechapp_user.session        TO speechapp_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON speechapp_user.turn           TO speechapp_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON speechapp_user.turn_image     TO speechapp_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON speechapp_user.voice_record   TO speechapp_app;

-- -----------------------------------------------------------
-- speechapp_user: cross-schema FK용 IMAGE_RESOURCE SELECT/REFERENCES (P3-20)
-- -----------------------------------------------------------
GRANT SELECT, REFERENCES ON speechapp_content.image_resource TO speechapp_user;

-- -----------------------------------------------------------
-- admin user: 두 스키마 모두 전체 권한
-- -----------------------------------------------------------
GRANT ALL ON speechapp_user.app_user       TO speechapp_admin;
GRANT ALL ON speechapp_user.user_profile     TO speechapp_admin;
GRANT ALL ON speechapp_content.image_resource TO speechapp_admin;

-- -----------------------------------------------------------
-- admin user: 신규 session/voice 테이블 전체 권한 (P3-20)
-- -----------------------------------------------------------
GRANT ALL ON speechapp_user.content_type   TO speechapp_admin;
GRANT ALL ON speechapp_user.session        TO speechapp_admin;
GRANT ALL ON speechapp_user.turn           TO speechapp_admin;
GRANT ALL ON speechapp_user.turn_image     TO speechapp_admin;
GRANT ALL ON speechapp_user.voice_record   TO speechapp_admin;
