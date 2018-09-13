INSERT INTO version (table_name, table_version) values ('b2b_sca','1');
CREATE TABLE b2b_sca (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    shared_line CHAR(64) NOT NULL,
    watchers CHAR(255) NOT NULL,
    app1_shared_entity INTEGER DEFAULT NULL,
    app1_call_state INTEGER DEFAULT NULL,
    app1_call_info_uri CHAR(256) DEFAULT NULL,
    app1_call_info_appearance_uri CHAR(256) DEFAULT NULL,
    app1_b2bl_key CHAR(64) DEFAULT NULL,
    app2_shared_entity INTEGER DEFAULT NULL,
    app2_call_state INTEGER DEFAULT NULL,
    app2_call_info_uri CHAR(256) DEFAULT NULL,
    app2_call_info_appearance_uri CHAR(256) DEFAULT NULL,
    app2_b2bl_key CHAR(64) DEFAULT NULL,
    app3_shared_entity INTEGER DEFAULT NULL,
    app3_call_state INTEGER DEFAULT NULL,
    app3_call_info_uri CHAR(256) DEFAULT NULL,
    app3_call_info_appearance_uri CHAR(256) DEFAULT NULL,
    app3_b2bl_key CHAR(64) DEFAULT NULL,
    app4_shared_entity INTEGER DEFAULT NULL,
    app4_call_state INTEGER DEFAULT NULL,
    app4_call_info_uri CHAR(256) DEFAULT NULL,
    app4_call_info_appearance_uri CHAR(256) DEFAULT NULL,
    app4_b2bl_key CHAR(64) DEFAULT NULL,
    app5_shared_entity INTEGER DEFAULT NULL,
    app5_call_state INTEGER DEFAULT NULL,
    app5_call_info_uri CHAR(256) DEFAULT NULL,
    app5_call_info_appearance_uri CHAR(256) DEFAULT NULL,
    app5_b2bl_key CHAR(64) DEFAULT NULL,
    app6_shared_entity INTEGER DEFAULT NULL,
    app6_call_state INTEGER DEFAULT NULL,
    app6_call_info_uri CHAR(256) DEFAULT NULL,
    app6_call_info_appearance_uri CHAR(256) DEFAULT NULL,
    app6_b2bl_key CHAR(64) DEFAULT NULL,
    app7_shared_entity INTEGER DEFAULT NULL,
    app7_call_state INTEGER DEFAULT NULL,
    app7_call_info_uri CHAR(256) DEFAULT NULL,
    app7_call_info_appearance_uri CHAR(256) DEFAULT NULL,
    app7_b2bl_key CHAR(64) DEFAULT NULL,
    app8_shared_entity INTEGER DEFAULT NULL,
    app8_call_state INTEGER DEFAULT NULL,
    app8_call_info_uri CHAR(256) DEFAULT NULL,
    app8_call_info_appearance_uri CHAR(256) DEFAULT NULL,
    app8_b2bl_key CHAR(64) DEFAULT NULL,
    app9_shared_entity INTEGER DEFAULT NULL,
    app9_call_state INTEGER DEFAULT NULL,
    app9_call_info_uri CHAR(256) DEFAULT NULL,
    app9_call_info_appearance_uri CHAR(256) DEFAULT NULL,
    app9_b2bl_key CHAR(64) DEFAULT NULL,
    app10_shared_entity INTEGER DEFAULT NULL,
    app10_call_state INTEGER DEFAULT NULL,
    app10_call_info_uri CHAR(256) DEFAULT NULL,
    app10_call_info_appearance_uri CHAR(256) DEFAULT NULL,
    app10_b2bl_key CHAR(64) DEFAULT NULL,
    CONSTRAINT b2b_sca_sca_idx  UNIQUE (shared_line)
);

