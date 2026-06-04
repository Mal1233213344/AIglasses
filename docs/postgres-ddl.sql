-- 儿童 AI 英语眼镜 PostgreSQL DDL（第一版草稿）
-- 生成日期：2026-03-26
-- 目标：覆盖第一阶段主链路所需核心表，可直接作为建库初稿。
-- 说明：本版优先包含核心业务表；推送 Token、内容发布流水、照片/对讲元数据、导出任务等扩展表可在 V2 增补。

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone varchar(20) NOT NULL,
  phone_country_code varchar(8) NOT NULL DEFAULT '+86',
  status varchar(32) NOT NULL DEFAULT 'active',
  last_login_at timestamptz NULL,
  current_device_id uuid NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  deleted_at timestamptz NULL,
  CONSTRAINT uk_users_phone UNIQUE (phone),
  CONSTRAINT ck_users_status CHECK (status IN ('active', 'locked', 'deleted'))
);

CREATE TABLE IF NOT EXISTS user_agreement_acceptances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  user_agreement_version varchar(32) NOT NULL,
  privacy_policy_version varchar(32) NOT NULL,
  child_privacy_version varchar(32) NOT NULL,
  accepted_at timestamptz NOT NULL DEFAULT NOW(),
  client_platform varchar(16) NOT NULL,
  client_version varchar(32) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_user_agreement_acceptances_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT ck_user_agreement_acceptances_platform CHECK (client_platform IN ('android', 'ios', 'unknown'))
);

CREATE TABLE IF NOT EXISTS user_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  refresh_token_hash varchar(255) NOT NULL,
  platform varchar(16) NOT NULL,
  device_model varchar(128) NULL,
  app_version varchar(32) NULL,
  ip_address varchar(64) NULL,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_user_sessions_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT ck_user_sessions_platform CHECK (platform IN ('android', 'ios'))
);

CREATE TABLE IF NOT EXISTS child_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  nickname varchar(32) NOT NULL,
  age smallint NULL,
  learning_stage varchar(32) NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT uk_child_profiles_user_id UNIQUE (user_id),
  CONSTRAINT fk_child_profiles_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT ck_child_profiles_age CHECK (age IS NULL OR age BETWEEN 2 AND 12),
  CONSTRAINT ck_child_profiles_learning_stage CHECK (learning_stage IS NULL OR learning_stage IN ('启蒙', '初级', '进阶'))
);

CREATE TABLE IF NOT EXISTS admin_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone varchar(20) NOT NULL,
  name varchar(64) NOT NULL,
  password_hash varchar(255) NOT NULL,
  role_code varchar(32) NOT NULL,
  status varchar(32) NOT NULL DEFAULT 'active',
  last_login_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT uk_admin_users_phone UNIQUE (phone),
  CONSTRAINT ck_admin_users_status CHECK (status IN ('active', 'locked', 'deleted'))
);

CREATE TABLE IF NOT EXISTS devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_sn varchar(64) NULL,
  bluetooth_mac varchar(32) NOT NULL,
  wifi_mac varchar(32) NULL,
  model_code varchar(16) NOT NULL,
  device_name varchar(64) NULL,
  firmware_version varchar(64) NULL,
  activation_at timestamptz NULL,
  last_online_at timestamptz NULL,
  status varchar(32) NOT NULL DEFAULT 'inactive',
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT uk_devices_device_sn UNIQUE (device_sn),
  CONSTRAINT uk_devices_bluetooth_mac UNIQUE (bluetooth_mac),
  CONSTRAINT ck_devices_model_code CHECK (model_code IN ('STD', 'PRO', 'MAX')),
  CONSTRAINT ck_devices_status CHECK (status IN ('inactive', 'active', 'disabled', 'deleted'))
);

DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_users_current_device_id'
  ) THEN
    ALTER TABLE users
      ADD CONSTRAINT fk_users_current_device_id
      FOREIGN KEY (current_device_id) REFERENCES devices(id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;
  END IF;
END
$do$;

CREATE TABLE IF NOT EXISTS device_bindings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL,
  user_id uuid NOT NULL,
  binding_status varchar(32) NOT NULL DEFAULT 'active',
  is_controller boolean NOT NULL DEFAULT true,
  remark_name varchar(64) NULL,
  bound_at timestamptz NOT NULL DEFAULT NOW(),
  unbound_at timestamptz NULL,
  unbind_reason varchar(64) NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_device_bindings_device_id FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
  CONSTRAINT fk_device_bindings_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT ck_device_bindings_status CHECK (binding_status IN ('active', 'unbound', 'replaced', 'revoked')),
  CONSTRAINT ck_device_bindings_unbound_at CHECK (unbound_at IS NULL OR unbound_at >= bound_at)
);

CREATE TABLE IF NOT EXISTS device_status_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL,
  online_status varchar(32) NOT NULL,
  battery_level smallint NULL,
  battery_state varchar(32) NULL,
  bluetooth_connected boolean NOT NULL DEFAULT false,
  wifi_connected boolean NOT NULL DEFAULT false,
  current_mode varchar(32) NULL,
  latest_alert_code varchar(64) NULL,
  telemetry jsonb NULL,
  reported_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_device_status_snapshots_device_id FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
  CONSTRAINT ck_device_status_snapshots_online_status CHECK (online_status IN ('online', 'offline', 'disconnected')),
  CONSTRAINT ck_device_status_snapshots_battery_level CHECK (battery_level IS NULL OR battery_level BETWEEN 0 AND 100),
  CONSTRAINT ck_device_status_snapshots_battery_state CHECK (battery_state IS NULL OR battery_state IN ('normal', 'low_20', 'low_10', 'charging'))
);

CREATE TABLE IF NOT EXISTS device_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL,
  max_volume_db smallint NOT NULL DEFAULT 85,
  volume_button_locked boolean NOT NULL DEFAULT false,
  single_session_limit_minutes smallint NULL,
  daily_limit_minutes smallint NULL,
  power_save_enabled boolean NOT NULL DEFAULT false,
  eye_care_interval_minutes smallint NULL,
  photo_auto_sync_enabled boolean NOT NULL DEFAULT false,
  photo_capture_permission_enabled boolean NOT NULL DEFAULT true,
  feature_switches jsonb NOT NULL DEFAULT '{}'::jsonb,
  version_no integer NOT NULL DEFAULT 1,
  updated_by_user_id uuid NULL,
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  created_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT uk_device_policies_device_id UNIQUE (device_id),
  CONSTRAINT fk_device_policies_device_id FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
  CONSTRAINT fk_device_policies_updated_by_user_id FOREIGN KEY (updated_by_user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT ck_device_policies_max_volume CHECK (max_volume_db BETWEEN 50 AND 100),
  CONSTRAINT ck_device_policies_single_session CHECK (single_session_limit_minutes IS NULL OR single_session_limit_minutes IN (10, 20, 30, 45, 60)),
  CONSTRAINT ck_device_policies_daily_limit CHECK (daily_limit_minutes IS NULL OR daily_limit_minutes BETWEEN 10 AND 600),
  CONSTRAINT ck_device_policies_eye_care CHECK (eye_care_interval_minutes IS NULL OR eye_care_interval_minutes IN (15, 20, 30)),
  CONSTRAINT ck_device_policies_version_no CHECK (version_no > 0),
  CONSTRAINT ck_device_policies_feature_switches_json CHECK (jsonb_typeof(feature_switches) = 'object')
);

CREATE TABLE IF NOT EXISTS device_commands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL,
  user_id uuid NULL,
  source_type varchar(32) NOT NULL,
  command_type varchar(64) NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status varchar(32) NOT NULL DEFAULT 'queued',
  offline_ttl_hours integer NOT NULL DEFAULT 24,
  expire_at timestamptz NOT NULL,
  delivered_at timestamptz NULL,
  executed_at timestamptz NULL,
  error_code varchar(64) NULL,
  error_message varchar(255) NULL,
  idempotency_key varchar(64) NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_device_commands_device_id FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
  CONSTRAINT fk_device_commands_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT ck_device_commands_source_type CHECK (source_type IN ('app', 'admin', 'system')),
  CONSTRAINT ck_device_commands_status CHECK (status IN ('queued', 'delivered', 'device_ack', 'succeeded', 'failed', 'expired', 'canceled')),
  CONSTRAINT ck_device_commands_ttl CHECK (offline_ttl_hours BETWEEN 1 AND 168),
  CONSTRAINT ck_device_commands_payload_json CHECK (jsonb_typeof(payload) = 'object')
);

CREATE TABLE IF NOT EXISTS learning_daily_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL,
  user_id uuid NOT NULL,
  stat_date date NOT NULL,
  study_minutes integer NOT NULL DEFAULT 0,
  recognized_word_count integer NOT NULL DEFAULT 0,
  follow_read_count integer NOT NULL DEFAULT 0,
  photo_count integer NOT NULL DEFAULT 0,
  intercom_call_count integer NOT NULL DEFAULT 0,
  streak_days integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT uk_learning_daily_stats_device_date UNIQUE (device_id, stat_date),
  CONSTRAINT fk_learning_daily_stats_device_id FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
  CONSTRAINT fk_learning_daily_stats_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT ck_learning_daily_stats_non_negative CHECK (
    study_minutes >= 0 AND recognized_word_count >= 0 AND follow_read_count >= 0 AND photo_count >= 0 AND intercom_call_count >= 0 AND streak_days >= 0
  )
);

CREATE TABLE IF NOT EXISTS learning_word_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL,
  user_id uuid NOT NULL,
  batch_id varchar(64) NULL,
  word varchar(128) NOT NULL,
  phonetic varchar(128) NULL,
  meaning_cn varchar(255) NULL,
  audio_url varchar(512) NULL,
  is_collected boolean NOT NULL DEFAULT false,
  recognized_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_learning_word_records_device_id FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
  CONSTRAINT fk_learning_word_records_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS reading_practice_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL,
  user_id uuid NOT NULL,
  batch_id varchar(64) NULL,
  sentence_text text NULL,
  score numeric(5,2) NULL,
  issue_tags jsonb NULL,
  standard_audio_url varchar(512) NULL,
  practice_duration_seconds integer NULL,
  practiced_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_reading_practice_records_device_id FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
  CONSTRAINT fk_reading_practice_records_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT ck_reading_practice_records_score CHECK (score IS NULL OR (score >= 0 AND score <= 100)),
  CONSTRAINT ck_reading_practice_records_duration CHECK (practice_duration_seconds IS NULL OR practice_duration_seconds >= 0),
  CONSTRAINT ck_reading_practice_records_issue_tags_json CHECK (issue_tags IS NULL OR jsonb_typeof(issue_tags) = 'array')
);

CREATE TABLE IF NOT EXISTS content_packages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  package_type varchar(16) NOT NULL,
  title varchar(128) NOT NULL,
  category varchar(64) NOT NULL,
  version varchar(32) NOT NULL,
  model_codes jsonb NOT NULL DEFAULT '[]'::jsonb,
  file_size_bytes bigint NOT NULL,
  checksum_sha256 varchar(128) NOT NULL,
  object_key varchar(255) NOT NULL,
  status varchar(32) NOT NULL DEFAULT 'draft',
  auto_update_enabled boolean NOT NULL DEFAULT false,
  created_by uuid NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_content_packages_created_by FOREIGN KEY (created_by) REFERENCES admin_users(id) ON DELETE SET NULL,
  CONSTRAINT ck_content_packages_type CHECK (package_type IN ('wordbook', 'audio')),
  CONSTRAINT ck_content_packages_status CHECK (status IN ('draft', 'review', 'published', 'archived')),
  CONSTRAINT ck_content_packages_file_size CHECK (file_size_bytes > 0),
  CONSTRAINT ck_content_packages_model_codes_json CHECK (jsonb_typeof(model_codes) = 'array')
);

CREATE TABLE IF NOT EXISTS firmware_packages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_code varchar(16) NOT NULL,
  version varchar(32) NOT NULL,
  min_battery_level smallint NOT NULL DEFAULT 30,
  checksum_sha256 varchar(128) NOT NULL,
  file_size_bytes bigint NOT NULL,
  object_key varchar(255) NOT NULL,
  release_notes text NULL,
  status varchar(32) NOT NULL DEFAULT 'draft',
  created_by uuid NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT uk_firmware_packages_model_version UNIQUE (model_code, version),
  CONSTRAINT fk_firmware_packages_created_by FOREIGN KEY (created_by) REFERENCES admin_users(id) ON DELETE SET NULL,
  CONSTRAINT ck_firmware_packages_model_code CHECK (model_code IN ('STD', 'PRO', 'MAX')),
  CONSTRAINT ck_firmware_packages_status CHECK (status IN ('draft', 'ready', 'published', 'archived')),
  CONSTRAINT ck_firmware_packages_battery CHECK (min_battery_level BETWEEN 1 AND 100),
  CONSTRAINT ck_firmware_packages_file_size CHECK (file_size_bytes > 0)
);

CREATE TABLE IF NOT EXISTS firmware_upgrade_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL,
  firmware_package_id uuid NOT NULL,
  trigger_source varchar(32) NOT NULL,
  status varchar(32) NOT NULL DEFAULT 'pending',
  progress_percent smallint NOT NULL DEFAULT 0,
  from_version varchar(32) NOT NULL,
  to_version varchar(32) NOT NULL,
  error_code varchar(64) NULL,
  error_message varchar(255) NULL,
  started_at timestamptz NULL,
  finished_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_firmware_upgrade_tasks_device_id FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
  CONSTRAINT fk_firmware_upgrade_tasks_package_id FOREIGN KEY (firmware_package_id) REFERENCES firmware_packages(id) ON DELETE RESTRICT,
  CONSTRAINT ck_firmware_upgrade_tasks_trigger_source CHECK (trigger_source IN ('app', 'device', 'admin', 'system')),
  CONSTRAINT ck_firmware_upgrade_tasks_status CHECK (status IN ('pending', 'downloading', 'transferring', 'upgrading', 'rollback', 'succeeded', 'failed', 'canceled')),
  CONSTRAINT ck_firmware_upgrade_tasks_progress CHECK (progress_percent BETWEEN 0 AND 100),
  CONSTRAINT ck_firmware_upgrade_tasks_finished_at CHECK (finished_at IS NULL OR started_at IS NULL OR finished_at >= started_at)
);

CREATE TABLE IF NOT EXISTS feedback_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  device_id uuid NULL,
  category varchar(32) NOT NULL,
  title varchar(128) NOT NULL,
  description text NOT NULL,
  status varchar(32) NOT NULL DEFAULT 'open',
  assigned_admin_user_id uuid NULL,
  latest_reply_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_feedback_tickets_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_feedback_tickets_device_id FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL,
  CONSTRAINT fk_feedback_tickets_assigned_admin_user_id FOREIGN KEY (assigned_admin_user_id) REFERENCES admin_users(id) ON DELETE SET NULL,
  CONSTRAINT ck_feedback_tickets_category CHECK (category IN ('device_connection', 'ota', 'photo_sync', 'intercom', 'content_sync', 'other')),
  CONSTRAINT ck_feedback_tickets_status CHECK (status IN ('open', 'processing', 'resolved', 'closed'))
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id uuid NOT NULL,
  action_module varchar(64) NOT NULL,
  action_type varchar(64) NOT NULL,
  target_type varchar(64) NULL,
  target_id varchar(64) NULL,
  request_ip varchar(64) NULL,
  request_id varchar(64) NULL,
  result_status varchar(32) NOT NULL,
  details jsonb NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_audit_logs_admin_user_id FOREIGN KEY (admin_user_id) REFERENCES admin_users(id) ON DELETE RESTRICT,
  CONSTRAINT ck_audit_logs_result_status CHECK (result_status IN ('success', 'failed', 'denied')),
  CONSTRAINT ck_audit_logs_details_json CHECK (details IS NULL OR jsonb_typeof(details) = 'object')
);

CREATE TABLE IF NOT EXISTS system_configs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  config_group varchar(64) NOT NULL,
  config_key varchar(128) NOT NULL,
  scope_type varchar(32) NOT NULL DEFAULT 'global',
  scope_value varchar(64) NULL,
  config_value jsonb NOT NULL,
  version_no integer NOT NULL DEFAULT 1,
  updated_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_system_configs_updated_by FOREIGN KEY (updated_by) REFERENCES admin_users(id) ON DELETE RESTRICT,
  CONSTRAINT ck_system_configs_scope_type CHECK (scope_type IN ('global', 'model', 'user_segment')),
  CONSTRAINT ck_system_configs_version_no CHECK (version_no > 0)
);

CREATE INDEX IF NOT EXISTS idx_user_agreement_acceptances_user_id ON user_agreement_acceptances (user_id, accepted_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON user_sessions (expires_at);
CREATE INDEX IF NOT EXISTS idx_users_status_created_at ON users (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_users_role_status ON admin_users (role_code, status);

CREATE INDEX IF NOT EXISTS idx_devices_model_status ON devices (model_code, status);
CREATE INDEX IF NOT EXISTS idx_devices_last_online_at ON devices (last_online_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_bindings_user_status ON device_bindings (user_id, binding_status, bound_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_bindings_device_status ON device_bindings (device_id, binding_status, bound_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_active_controller_per_device ON device_bindings (device_id) WHERE binding_status = 'active' AND is_controller = true;
CREATE UNIQUE INDEX IF NOT EXISTS uniq_active_binding_per_user_device ON device_bindings (user_id, device_id) WHERE binding_status = 'active';
CREATE INDEX IF NOT EXISTS idx_device_status_snapshots_device_time ON device_status_snapshots (device_id, reported_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_commands_device_status_created ON device_commands (device_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_commands_expire_at ON device_commands (expire_at);
CREATE INDEX IF NOT EXISTS idx_device_commands_user_created ON device_commands (user_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_device_commands_idempotency ON device_commands (device_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_learning_daily_stats_user_date ON learning_daily_stats (user_id, stat_date DESC);
CREATE INDEX IF NOT EXISTS idx_learning_word_records_device_time ON learning_word_records (device_id, recognized_at DESC);
CREATE INDEX IF NOT EXISTS idx_learning_word_records_user_word ON learning_word_records (user_id, word);
CREATE INDEX IF NOT EXISTS idx_learning_word_records_batch_id ON learning_word_records (batch_id);
CREATE INDEX IF NOT EXISTS idx_reading_practice_records_device_time ON reading_practice_records (device_id, practiced_at DESC);
CREATE INDEX IF NOT EXISTS idx_reading_practice_records_user_time ON reading_practice_records (user_id, practiced_at DESC);

CREATE INDEX IF NOT EXISTS idx_content_packages_type_status ON content_packages (package_type, status);
CREATE INDEX IF NOT EXISTS idx_content_packages_version ON content_packages (version);
CREATE INDEX IF NOT EXISTS idx_firmware_packages_status_created ON firmware_packages (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_firmware_upgrade_tasks_device_created ON firmware_upgrade_tasks (device_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_firmware_upgrade_tasks_status_created ON firmware_upgrade_tasks (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_feedback_tickets_user_created ON feedback_tickets (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_tickets_status_created ON feedback_tickets (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_admin_time ON audit_logs (admin_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_module_time ON audit_logs (action_module, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_system_configs_scope ON system_configs (config_group, config_key, scope_type, COALESCE(scope_value, '__NULL__'));

DROP TRIGGER IF EXISTS trg_users_set_updated_at ON users;
CREATE TRIGGER trg_users_set_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_child_profiles_set_updated_at ON child_profiles;
CREATE TRIGGER trg_child_profiles_set_updated_at BEFORE UPDATE ON child_profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_admin_users_set_updated_at ON admin_users;
CREATE TRIGGER trg_admin_users_set_updated_at BEFORE UPDATE ON admin_users FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_devices_set_updated_at ON devices;
CREATE TRIGGER trg_devices_set_updated_at BEFORE UPDATE ON devices FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_device_bindings_set_updated_at ON device_bindings;
CREATE TRIGGER trg_device_bindings_set_updated_at BEFORE UPDATE ON device_bindings FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_device_policies_set_updated_at ON device_policies;
CREATE TRIGGER trg_device_policies_set_updated_at BEFORE UPDATE ON device_policies FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_learning_daily_stats_set_updated_at ON learning_daily_stats;
CREATE TRIGGER trg_learning_daily_stats_set_updated_at BEFORE UPDATE ON learning_daily_stats FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_content_packages_set_updated_at ON content_packages;
CREATE TRIGGER trg_content_packages_set_updated_at BEFORE UPDATE ON content_packages FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_firmware_packages_set_updated_at ON firmware_packages;
CREATE TRIGGER trg_firmware_packages_set_updated_at BEFORE UPDATE ON firmware_packages FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_feedback_tickets_set_updated_at ON feedback_tickets;
CREATE TRIGGER trg_feedback_tickets_set_updated_at BEFORE UPDATE ON feedback_tickets FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_system_configs_set_updated_at ON system_configs;
CREATE TRIGGER trg_system_configs_set_updated_at BEFORE UPDATE ON system_configs FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;


