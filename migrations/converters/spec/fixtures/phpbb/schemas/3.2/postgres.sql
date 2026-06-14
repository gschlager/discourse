--
-- PostgreSQL database dump
--

\restrict jUFXBXkU9OKeNgjjaU6XnUYZkk7P4W1XOv5NMSiwK1Pm27Idb9ameSsOEhPXnbj

-- Dumped from database version 16.14 (Debian 16.14-1.pgdg13+1)
-- Dumped by pg_dump version 16.14 (Debian 16.14-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: varchar_ci; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.varchar_ci AS character varying(255) NOT NULL DEFAULT ''::character varying;


--
-- Name: _varchar_ci_equal(public.varchar_ci, public.varchar_ci); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._varchar_ci_equal(public.varchar_ci, public.varchar_ci) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$SELECT LOWER($1) = LOWER($2)$_$;


--
-- Name: _varchar_ci_greater_equals(public.varchar_ci, public.varchar_ci); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._varchar_ci_greater_equals(public.varchar_ci, public.varchar_ci) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$SELECT LOWER($1) >= LOWER($2)$_$;


--
-- Name: _varchar_ci_greater_than(public.varchar_ci, public.varchar_ci); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._varchar_ci_greater_than(public.varchar_ci, public.varchar_ci) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$SELECT LOWER($1) > LOWER($2)$_$;


--
-- Name: _varchar_ci_less_equal(public.varchar_ci, public.varchar_ci); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._varchar_ci_less_equal(public.varchar_ci, public.varchar_ci) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$SELECT LOWER($1) <= LOWER($2)$_$;


--
-- Name: _varchar_ci_less_than(public.varchar_ci, public.varchar_ci); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._varchar_ci_less_than(public.varchar_ci, public.varchar_ci) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$SELECT LOWER($1) < LOWER($2)$_$;


--
-- Name: _varchar_ci_not_equal(public.varchar_ci, public.varchar_ci); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._varchar_ci_not_equal(public.varchar_ci, public.varchar_ci) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$SELECT LOWER($1) != LOWER($2)$_$;


--
-- Name: <; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.< (
    FUNCTION = public._varchar_ci_less_than,
    LEFTARG = public.varchar_ci,
    RIGHTARG = public.varchar_ci,
    COMMUTATOR = OPERATOR(public.>),
    NEGATOR = OPERATOR(public.>=),
    RESTRICT = scalarltsel,
    JOIN = scalarltjoinsel
);


--
-- Name: <=; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.<= (
    FUNCTION = public._varchar_ci_less_equal,
    LEFTARG = public.varchar_ci,
    RIGHTARG = public.varchar_ci,
    COMMUTATOR = OPERATOR(public.>=),
    NEGATOR = OPERATOR(public.>),
    RESTRICT = scalarltsel,
    JOIN = scalarltjoinsel
);


--
-- Name: <>; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.<> (
    FUNCTION = public._varchar_ci_not_equal,
    LEFTARG = public.varchar_ci,
    RIGHTARG = public.varchar_ci,
    COMMUTATOR = OPERATOR(public.<>),
    NEGATOR = OPERATOR(public.=),
    RESTRICT = neqsel,
    JOIN = neqjoinsel
);


--
-- Name: =; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.= (
    FUNCTION = public._varchar_ci_equal,
    LEFTARG = public.varchar_ci,
    RIGHTARG = public.varchar_ci,
    COMMUTATOR = OPERATOR(public.=),
    NEGATOR = OPERATOR(public.<>),
    MERGES,
    HASHES,
    RESTRICT = eqsel,
    JOIN = eqjoinsel
);


--
-- Name: >; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.> (
    FUNCTION = public._varchar_ci_greater_than,
    LEFTARG = public.varchar_ci,
    RIGHTARG = public.varchar_ci,
    COMMUTATOR = OPERATOR(public.<),
    NEGATOR = OPERATOR(public.<=),
    RESTRICT = scalargtsel,
    JOIN = scalargtjoinsel
);


--
-- Name: >=; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.>= (
    FUNCTION = public._varchar_ci_greater_equals,
    LEFTARG = public.varchar_ci,
    RIGHTARG = public.varchar_ci,
    COMMUTATOR = OPERATOR(public.<=),
    NEGATOR = OPERATOR(public.<),
    RESTRICT = scalargtsel,
    JOIN = scalargtjoinsel
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: phpbb_acl_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_acl_groups (
    group_id integer DEFAULT 0 NOT NULL,
    forum_id integer DEFAULT 0 NOT NULL,
    auth_option_id integer DEFAULT 0 NOT NULL,
    auth_role_id integer DEFAULT 0 NOT NULL,
    auth_setting smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_acl_groups_auth_option_id_check CHECK ((auth_option_id >= 0)),
    CONSTRAINT phpbb_acl_groups_auth_role_id_check CHECK ((auth_role_id >= 0)),
    CONSTRAINT phpbb_acl_groups_forum_id_check CHECK ((forum_id >= 0)),
    CONSTRAINT phpbb_acl_groups_group_id_check CHECK ((group_id >= 0))
);


--
-- Name: phpbb_acl_options_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_acl_options_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_acl_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_acl_options (
    auth_option_id integer DEFAULT nextval('public.phpbb_acl_options_seq'::regclass) NOT NULL,
    auth_option character varying(50) DEFAULT ''::character varying NOT NULL,
    is_global smallint DEFAULT '0'::smallint NOT NULL,
    is_local smallint DEFAULT '0'::smallint NOT NULL,
    founder_only smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_acl_options_auth_option_id_check CHECK ((auth_option_id >= 0)),
    CONSTRAINT phpbb_acl_options_founder_only_check CHECK ((founder_only >= 0)),
    CONSTRAINT phpbb_acl_options_is_global_check CHECK ((is_global >= 0)),
    CONSTRAINT phpbb_acl_options_is_local_check CHECK ((is_local >= 0))
);


--
-- Name: phpbb_acl_roles_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_acl_roles_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_acl_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_acl_roles (
    role_id integer DEFAULT nextval('public.phpbb_acl_roles_seq'::regclass) NOT NULL,
    role_name character varying(255) DEFAULT ''::character varying NOT NULL,
    role_description character varying(4000) DEFAULT ''::character varying NOT NULL,
    role_type character varying(10) DEFAULT ''::character varying NOT NULL,
    role_order smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_acl_roles_role_id_check CHECK ((role_id >= 0)),
    CONSTRAINT phpbb_acl_roles_role_order_check CHECK ((role_order >= 0))
);


--
-- Name: phpbb_acl_roles_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_acl_roles_data (
    role_id integer DEFAULT 0 NOT NULL,
    auth_option_id integer DEFAULT 0 NOT NULL,
    auth_setting smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_acl_roles_data_auth_option_id_check CHECK ((auth_option_id >= 0)),
    CONSTRAINT phpbb_acl_roles_data_role_id_check CHECK ((role_id >= 0))
);


--
-- Name: phpbb_acl_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_acl_users (
    user_id integer DEFAULT 0 NOT NULL,
    forum_id integer DEFAULT 0 NOT NULL,
    auth_option_id integer DEFAULT 0 NOT NULL,
    auth_role_id integer DEFAULT 0 NOT NULL,
    auth_setting smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_acl_users_auth_option_id_check CHECK ((auth_option_id >= 0)),
    CONSTRAINT phpbb_acl_users_auth_role_id_check CHECK ((auth_role_id >= 0)),
    CONSTRAINT phpbb_acl_users_forum_id_check CHECK ((forum_id >= 0)),
    CONSTRAINT phpbb_acl_users_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_attachments_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_attachments_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_attachments (
    attach_id integer DEFAULT nextval('public.phpbb_attachments_seq'::regclass) NOT NULL,
    post_msg_id integer DEFAULT 0 NOT NULL,
    topic_id integer DEFAULT 0 NOT NULL,
    in_message smallint DEFAULT '0'::smallint NOT NULL,
    poster_id integer DEFAULT 0 NOT NULL,
    is_orphan smallint DEFAULT '1'::smallint NOT NULL,
    physical_filename character varying(255) DEFAULT ''::character varying NOT NULL,
    real_filename character varying(255) DEFAULT ''::character varying NOT NULL,
    download_count integer DEFAULT 0 NOT NULL,
    attach_comment character varying(4000) DEFAULT ''::character varying NOT NULL,
    extension character varying(100) DEFAULT ''::character varying NOT NULL,
    mimetype character varying(100) DEFAULT ''::character varying NOT NULL,
    filesize integer DEFAULT 0 NOT NULL,
    filetime integer DEFAULT 0 NOT NULL,
    thumbnail smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_attachments_attach_id_check CHECK ((attach_id >= 0)),
    CONSTRAINT phpbb_attachments_download_count_check CHECK ((download_count >= 0)),
    CONSTRAINT phpbb_attachments_filesize_check CHECK ((filesize >= 0)),
    CONSTRAINT phpbb_attachments_filetime_check CHECK ((filetime >= 0)),
    CONSTRAINT phpbb_attachments_in_message_check CHECK ((in_message >= 0)),
    CONSTRAINT phpbb_attachments_is_orphan_check CHECK ((is_orphan >= 0)),
    CONSTRAINT phpbb_attachments_post_msg_id_check CHECK ((post_msg_id >= 0)),
    CONSTRAINT phpbb_attachments_poster_id_check CHECK ((poster_id >= 0)),
    CONSTRAINT phpbb_attachments_thumbnail_check CHECK ((thumbnail >= 0)),
    CONSTRAINT phpbb_attachments_topic_id_check CHECK ((topic_id >= 0))
);


--
-- Name: phpbb_banlist_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_banlist_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_banlist; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_banlist (
    ban_id integer DEFAULT nextval('public.phpbb_banlist_seq'::regclass) NOT NULL,
    ban_userid integer DEFAULT 0 NOT NULL,
    ban_ip character varying(40) DEFAULT ''::character varying NOT NULL,
    ban_email character varying(100) DEFAULT ''::character varying NOT NULL,
    ban_start integer DEFAULT 0 NOT NULL,
    ban_end integer DEFAULT 0 NOT NULL,
    ban_exclude smallint DEFAULT '0'::smallint NOT NULL,
    ban_reason character varying(255) DEFAULT ''::character varying NOT NULL,
    ban_give_reason character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_banlist_ban_end_check CHECK ((ban_end >= 0)),
    CONSTRAINT phpbb_banlist_ban_exclude_check CHECK ((ban_exclude >= 0)),
    CONSTRAINT phpbb_banlist_ban_id_check CHECK ((ban_id >= 0)),
    CONSTRAINT phpbb_banlist_ban_start_check CHECK ((ban_start >= 0)),
    CONSTRAINT phpbb_banlist_ban_userid_check CHECK ((ban_userid >= 0))
);


--
-- Name: phpbb_bbcodes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_bbcodes (
    bbcode_id smallint DEFAULT '0'::smallint NOT NULL,
    bbcode_tag character varying(16) DEFAULT ''::character varying NOT NULL,
    bbcode_helpline character varying(255) DEFAULT ''::character varying NOT NULL,
    display_on_posting smallint DEFAULT '0'::smallint NOT NULL,
    bbcode_match character varying(4000) DEFAULT ''::character varying NOT NULL,
    bbcode_tpl text DEFAULT ''::text NOT NULL,
    first_pass_match text DEFAULT ''::text NOT NULL,
    first_pass_replace text DEFAULT ''::text NOT NULL,
    second_pass_match text DEFAULT ''::text NOT NULL,
    second_pass_replace text DEFAULT ''::text NOT NULL,
    CONSTRAINT phpbb_bbcodes_bbcode_id_check CHECK ((bbcode_id >= 0)),
    CONSTRAINT phpbb_bbcodes_display_on_posting_check CHECK ((display_on_posting >= 0))
);


--
-- Name: phpbb_bookmarks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_bookmarks (
    topic_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_bookmarks_topic_id_check CHECK ((topic_id >= 0)),
    CONSTRAINT phpbb_bookmarks_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_bots_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_bots_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_bots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_bots (
    bot_id integer DEFAULT nextval('public.phpbb_bots_seq'::regclass) NOT NULL,
    bot_active smallint DEFAULT '1'::smallint NOT NULL,
    bot_name character varying(255) DEFAULT ''::character varying NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    bot_agent character varying(255) DEFAULT ''::character varying NOT NULL,
    bot_ip character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_bots_bot_active_check CHECK ((bot_active >= 0)),
    CONSTRAINT phpbb_bots_bot_id_check CHECK ((bot_id >= 0)),
    CONSTRAINT phpbb_bots_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_config (
    config_name character varying(255) DEFAULT ''::character varying NOT NULL,
    config_value character varying(255) DEFAULT ''::character varying NOT NULL,
    is_dynamic smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_config_is_dynamic_check CHECK ((is_dynamic >= 0))
);


--
-- Name: phpbb_config_text; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_config_text (
    config_name character varying(255) DEFAULT ''::character varying NOT NULL,
    config_value text DEFAULT ''::text NOT NULL
);


--
-- Name: phpbb_confirm; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_confirm (
    confirm_id character(32) DEFAULT ''::bpchar NOT NULL,
    session_id character(32) DEFAULT ''::bpchar NOT NULL,
    confirm_type smallint DEFAULT '0'::smallint NOT NULL,
    code character varying(8) DEFAULT ''::character varying NOT NULL,
    seed integer DEFAULT 0 NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_confirm_attempts_check CHECK ((attempts >= 0)),
    CONSTRAINT phpbb_confirm_seed_check CHECK ((seed >= 0))
);


--
-- Name: phpbb_disallow_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_disallow_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_disallow; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_disallow (
    disallow_id integer DEFAULT nextval('public.phpbb_disallow_seq'::regclass) NOT NULL,
    disallow_username character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_disallow_disallow_id_check CHECK ((disallow_id >= 0))
);


--
-- Name: phpbb_drafts_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_drafts_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_drafts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_drafts (
    draft_id integer DEFAULT nextval('public.phpbb_drafts_seq'::regclass) NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    topic_id integer DEFAULT 0 NOT NULL,
    forum_id integer DEFAULT 0 NOT NULL,
    save_time integer DEFAULT 0 NOT NULL,
    draft_subject character varying(255) DEFAULT ''::character varying NOT NULL,
    draft_message text DEFAULT ''::text NOT NULL,
    CONSTRAINT phpbb_drafts_draft_id_check CHECK ((draft_id >= 0)),
    CONSTRAINT phpbb_drafts_forum_id_check CHECK ((forum_id >= 0)),
    CONSTRAINT phpbb_drafts_save_time_check CHECK ((save_time >= 0)),
    CONSTRAINT phpbb_drafts_topic_id_check CHECK ((topic_id >= 0)),
    CONSTRAINT phpbb_drafts_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_ext; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_ext (
    ext_name character varying(255) DEFAULT ''::character varying NOT NULL,
    ext_active smallint DEFAULT '0'::smallint NOT NULL,
    ext_state character varying(8000) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_ext_ext_active_check CHECK ((ext_active >= 0))
);


--
-- Name: phpbb_extension_groups_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_extension_groups_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_extension_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_extension_groups (
    group_id integer DEFAULT nextval('public.phpbb_extension_groups_seq'::regclass) NOT NULL,
    group_name character varying(255) DEFAULT ''::character varying NOT NULL,
    cat_id smallint DEFAULT '0'::smallint NOT NULL,
    allow_group smallint DEFAULT '0'::smallint NOT NULL,
    download_mode smallint DEFAULT '1'::smallint NOT NULL,
    upload_icon character varying(255) DEFAULT ''::character varying NOT NULL,
    max_filesize integer DEFAULT 0 NOT NULL,
    allowed_forums character varying(8000) DEFAULT ''::character varying NOT NULL,
    allow_in_pm smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_extension_groups_allow_group_check CHECK ((allow_group >= 0)),
    CONSTRAINT phpbb_extension_groups_allow_in_pm_check CHECK ((allow_in_pm >= 0)),
    CONSTRAINT phpbb_extension_groups_download_mode_check CHECK ((download_mode >= 0)),
    CONSTRAINT phpbb_extension_groups_group_id_check CHECK ((group_id >= 0)),
    CONSTRAINT phpbb_extension_groups_max_filesize_check CHECK ((max_filesize >= 0))
);


--
-- Name: phpbb_extensions_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_extensions_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_extensions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_extensions (
    extension_id integer DEFAULT nextval('public.phpbb_extensions_seq'::regclass) NOT NULL,
    group_id integer DEFAULT 0 NOT NULL,
    extension character varying(100) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_extensions_extension_id_check CHECK ((extension_id >= 0)),
    CONSTRAINT phpbb_extensions_group_id_check CHECK ((group_id >= 0))
);


--
-- Name: phpbb_forums_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_forums_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_forums; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_forums (
    forum_id integer DEFAULT nextval('public.phpbb_forums_seq'::regclass) NOT NULL,
    parent_id integer DEFAULT 0 NOT NULL,
    left_id integer DEFAULT 0 NOT NULL,
    right_id integer DEFAULT 0 NOT NULL,
    forum_parents text DEFAULT ''::text NOT NULL,
    forum_name character varying(255) DEFAULT ''::character varying NOT NULL,
    forum_desc character varying(4000) DEFAULT ''::character varying NOT NULL,
    forum_desc_bitfield character varying(255) DEFAULT ''::character varying NOT NULL,
    forum_desc_options integer DEFAULT 7 NOT NULL,
    forum_desc_uid character varying(8) DEFAULT ''::character varying NOT NULL,
    forum_link character varying(255) DEFAULT ''::character varying NOT NULL,
    forum_password character varying(255) DEFAULT ''::character varying NOT NULL,
    forum_style integer DEFAULT 0 NOT NULL,
    forum_image character varying(255) DEFAULT ''::character varying NOT NULL,
    forum_rules character varying(4000) DEFAULT ''::character varying NOT NULL,
    forum_rules_link character varying(255) DEFAULT ''::character varying NOT NULL,
    forum_rules_bitfield character varying(255) DEFAULT ''::character varying NOT NULL,
    forum_rules_options integer DEFAULT 7 NOT NULL,
    forum_rules_uid character varying(8) DEFAULT ''::character varying NOT NULL,
    forum_topics_per_page smallint DEFAULT '0'::smallint NOT NULL,
    forum_type smallint DEFAULT '0'::smallint NOT NULL,
    forum_status smallint DEFAULT '0'::smallint NOT NULL,
    forum_last_post_id integer DEFAULT 0 NOT NULL,
    forum_last_poster_id integer DEFAULT 0 NOT NULL,
    forum_last_post_subject character varying(255) DEFAULT ''::character varying NOT NULL,
    forum_last_post_time integer DEFAULT 0 NOT NULL,
    forum_last_poster_name character varying(255) DEFAULT ''::character varying NOT NULL,
    forum_last_poster_colour character varying(6) DEFAULT ''::character varying NOT NULL,
    forum_flags smallint DEFAULT '32'::smallint NOT NULL,
    display_on_index smallint DEFAULT '1'::smallint NOT NULL,
    enable_indexing smallint DEFAULT '1'::smallint NOT NULL,
    enable_icons smallint DEFAULT '1'::smallint NOT NULL,
    enable_prune smallint DEFAULT '0'::smallint NOT NULL,
    prune_next integer DEFAULT 0 NOT NULL,
    prune_days integer DEFAULT 0 NOT NULL,
    prune_viewed integer DEFAULT 0 NOT NULL,
    prune_freq integer DEFAULT 0 NOT NULL,
    display_subforum_list smallint DEFAULT '1'::smallint NOT NULL,
    forum_options integer DEFAULT 0 NOT NULL,
    enable_shadow_prune smallint DEFAULT '0'::smallint NOT NULL,
    prune_shadow_days integer DEFAULT 7 NOT NULL,
    prune_shadow_freq integer DEFAULT 1 NOT NULL,
    prune_shadow_next integer DEFAULT 0 NOT NULL,
    forum_posts_approved integer DEFAULT 0 NOT NULL,
    forum_posts_unapproved integer DEFAULT 0 NOT NULL,
    forum_posts_softdeleted integer DEFAULT 0 NOT NULL,
    forum_topics_approved integer DEFAULT 0 NOT NULL,
    forum_topics_unapproved integer DEFAULT 0 NOT NULL,
    forum_topics_softdeleted integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_forums_display_on_index_check CHECK ((display_on_index >= 0)),
    CONSTRAINT phpbb_forums_display_subforum_list_check CHECK ((display_subforum_list >= 0)),
    CONSTRAINT phpbb_forums_enable_icons_check CHECK ((enable_icons >= 0)),
    CONSTRAINT phpbb_forums_enable_indexing_check CHECK ((enable_indexing >= 0)),
    CONSTRAINT phpbb_forums_enable_prune_check CHECK ((enable_prune >= 0)),
    CONSTRAINT phpbb_forums_enable_shadow_prune_check CHECK ((enable_shadow_prune >= 0)),
    CONSTRAINT phpbb_forums_forum_desc_options_check CHECK ((forum_desc_options >= 0)),
    CONSTRAINT phpbb_forums_forum_id_check CHECK ((forum_id >= 0)),
    CONSTRAINT phpbb_forums_forum_last_post_id_check CHECK ((forum_last_post_id >= 0)),
    CONSTRAINT phpbb_forums_forum_last_post_time_check CHECK ((forum_last_post_time >= 0)),
    CONSTRAINT phpbb_forums_forum_last_poster_id_check CHECK ((forum_last_poster_id >= 0)),
    CONSTRAINT phpbb_forums_forum_options_check CHECK ((forum_options >= 0)),
    CONSTRAINT phpbb_forums_forum_posts_approved_check CHECK ((forum_posts_approved >= 0)),
    CONSTRAINT phpbb_forums_forum_posts_softdeleted_check CHECK ((forum_posts_softdeleted >= 0)),
    CONSTRAINT phpbb_forums_forum_posts_unapproved_check CHECK ((forum_posts_unapproved >= 0)),
    CONSTRAINT phpbb_forums_forum_rules_options_check CHECK ((forum_rules_options >= 0)),
    CONSTRAINT phpbb_forums_forum_style_check CHECK ((forum_style >= 0)),
    CONSTRAINT phpbb_forums_forum_topics_approved_check CHECK ((forum_topics_approved >= 0)),
    CONSTRAINT phpbb_forums_forum_topics_per_page_check CHECK ((forum_topics_per_page >= 0)),
    CONSTRAINT phpbb_forums_forum_topics_softdeleted_check CHECK ((forum_topics_softdeleted >= 0)),
    CONSTRAINT phpbb_forums_forum_topics_unapproved_check CHECK ((forum_topics_unapproved >= 0)),
    CONSTRAINT phpbb_forums_left_id_check CHECK ((left_id >= 0)),
    CONSTRAINT phpbb_forums_parent_id_check CHECK ((parent_id >= 0)),
    CONSTRAINT phpbb_forums_prune_days_check CHECK ((prune_days >= 0)),
    CONSTRAINT phpbb_forums_prune_freq_check CHECK ((prune_freq >= 0)),
    CONSTRAINT phpbb_forums_prune_next_check CHECK ((prune_next >= 0)),
    CONSTRAINT phpbb_forums_prune_shadow_days_check CHECK ((prune_shadow_days >= 0)),
    CONSTRAINT phpbb_forums_prune_shadow_freq_check CHECK ((prune_shadow_freq >= 0)),
    CONSTRAINT phpbb_forums_prune_viewed_check CHECK ((prune_viewed >= 0)),
    CONSTRAINT phpbb_forums_right_id_check CHECK ((right_id >= 0))
);


--
-- Name: phpbb_forums_access; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_forums_access (
    forum_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    session_id character(32) DEFAULT ''::bpchar NOT NULL,
    CONSTRAINT phpbb_forums_access_forum_id_check CHECK ((forum_id >= 0)),
    CONSTRAINT phpbb_forums_access_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_forums_track; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_forums_track (
    user_id integer DEFAULT 0 NOT NULL,
    forum_id integer DEFAULT 0 NOT NULL,
    mark_time integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_forums_track_forum_id_check CHECK ((forum_id >= 0)),
    CONSTRAINT phpbb_forums_track_mark_time_check CHECK ((mark_time >= 0)),
    CONSTRAINT phpbb_forums_track_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_forums_watch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_forums_watch (
    forum_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    notify_status smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_forums_watch_forum_id_check CHECK ((forum_id >= 0)),
    CONSTRAINT phpbb_forums_watch_notify_status_check CHECK ((notify_status >= 0)),
    CONSTRAINT phpbb_forums_watch_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_groups_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_groups_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_groups (
    group_id integer DEFAULT nextval('public.phpbb_groups_seq'::regclass) NOT NULL,
    group_type smallint DEFAULT '1'::smallint NOT NULL,
    group_founder_manage smallint DEFAULT '0'::smallint NOT NULL,
    group_skip_auth smallint DEFAULT '0'::smallint NOT NULL,
    group_name public.varchar_ci DEFAULT ''::character varying NOT NULL,
    group_desc character varying(4000) DEFAULT ''::character varying NOT NULL,
    group_desc_bitfield character varying(255) DEFAULT ''::character varying NOT NULL,
    group_desc_options integer DEFAULT 7 NOT NULL,
    group_desc_uid character varying(8) DEFAULT ''::character varying NOT NULL,
    group_display smallint DEFAULT '0'::smallint NOT NULL,
    group_avatar character varying(255) DEFAULT ''::character varying NOT NULL,
    group_avatar_type character varying(255) DEFAULT ''::character varying NOT NULL,
    group_avatar_width smallint DEFAULT '0'::smallint NOT NULL,
    group_avatar_height smallint DEFAULT '0'::smallint NOT NULL,
    group_rank integer DEFAULT 0 NOT NULL,
    group_colour character varying(6) DEFAULT ''::character varying NOT NULL,
    group_sig_chars integer DEFAULT 0 NOT NULL,
    group_receive_pm smallint DEFAULT '0'::smallint NOT NULL,
    group_message_limit integer DEFAULT 0 NOT NULL,
    group_legend integer DEFAULT 0 NOT NULL,
    group_max_recipients integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_groups_group_avatar_height_check CHECK ((group_avatar_height >= 0)),
    CONSTRAINT phpbb_groups_group_avatar_width_check CHECK ((group_avatar_width >= 0)),
    CONSTRAINT phpbb_groups_group_desc_options_check CHECK ((group_desc_options >= 0)),
    CONSTRAINT phpbb_groups_group_display_check CHECK ((group_display >= 0)),
    CONSTRAINT phpbb_groups_group_founder_manage_check CHECK ((group_founder_manage >= 0)),
    CONSTRAINT phpbb_groups_group_id_check CHECK ((group_id >= 0)),
    CONSTRAINT phpbb_groups_group_legend_check CHECK ((group_legend >= 0)),
    CONSTRAINT phpbb_groups_group_max_recipients_check CHECK ((group_max_recipients >= 0)),
    CONSTRAINT phpbb_groups_group_message_limit_check CHECK ((group_message_limit >= 0)),
    CONSTRAINT phpbb_groups_group_rank_check CHECK ((group_rank >= 0)),
    CONSTRAINT phpbb_groups_group_receive_pm_check CHECK ((group_receive_pm >= 0)),
    CONSTRAINT phpbb_groups_group_sig_chars_check CHECK ((group_sig_chars >= 0)),
    CONSTRAINT phpbb_groups_group_skip_auth_check CHECK ((group_skip_auth >= 0))
);


--
-- Name: phpbb_icons_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_icons_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_icons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_icons (
    icons_id integer DEFAULT nextval('public.phpbb_icons_seq'::regclass) NOT NULL,
    icons_url character varying(255) DEFAULT ''::character varying NOT NULL,
    icons_width smallint DEFAULT '0'::smallint NOT NULL,
    icons_height smallint DEFAULT '0'::smallint NOT NULL,
    icons_alt character varying(255) DEFAULT ''::character varying NOT NULL,
    icons_order integer DEFAULT 0 NOT NULL,
    display_on_posting smallint DEFAULT '1'::smallint NOT NULL,
    CONSTRAINT phpbb_icons_display_on_posting_check CHECK ((display_on_posting >= 0)),
    CONSTRAINT phpbb_icons_icons_id_check CHECK ((icons_id >= 0)),
    CONSTRAINT phpbb_icons_icons_order_check CHECK ((icons_order >= 0))
);


--
-- Name: phpbb_lang_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_lang_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_lang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_lang (
    lang_id smallint DEFAULT nextval('public.phpbb_lang_seq'::regclass) NOT NULL,
    lang_iso character varying(30) DEFAULT ''::character varying NOT NULL,
    lang_dir character varying(30) DEFAULT ''::character varying NOT NULL,
    lang_english_name character varying(100) DEFAULT ''::character varying NOT NULL,
    lang_local_name character varying(255) DEFAULT ''::character varying NOT NULL,
    lang_author character varying(255) DEFAULT ''::character varying NOT NULL
);


--
-- Name: phpbb_log_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_log_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_log (
    log_id integer DEFAULT nextval('public.phpbb_log_seq'::regclass) NOT NULL,
    log_type smallint DEFAULT '0'::smallint NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    forum_id integer DEFAULT 0 NOT NULL,
    topic_id integer DEFAULT 0 NOT NULL,
    post_id integer DEFAULT 0 NOT NULL,
    reportee_id integer DEFAULT 0 NOT NULL,
    log_ip character varying(40) DEFAULT ''::character varying NOT NULL,
    log_time integer DEFAULT 0 NOT NULL,
    log_operation character varying(4000) DEFAULT ''::character varying NOT NULL,
    log_data text DEFAULT ''::text NOT NULL,
    CONSTRAINT phpbb_log_forum_id_check CHECK ((forum_id >= 0)),
    CONSTRAINT phpbb_log_log_id_check CHECK ((log_id >= 0)),
    CONSTRAINT phpbb_log_log_time_check CHECK ((log_time >= 0)),
    CONSTRAINT phpbb_log_post_id_check CHECK ((post_id >= 0)),
    CONSTRAINT phpbb_log_reportee_id_check CHECK ((reportee_id >= 0)),
    CONSTRAINT phpbb_log_topic_id_check CHECK ((topic_id >= 0)),
    CONSTRAINT phpbb_log_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_login_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_login_attempts (
    attempt_ip character varying(40) DEFAULT ''::character varying NOT NULL,
    attempt_browser character varying(150) DEFAULT ''::character varying NOT NULL,
    attempt_forwarded_for character varying(255) DEFAULT ''::character varying NOT NULL,
    attempt_time integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    username character varying(255) DEFAULT '0'::character varying NOT NULL,
    username_clean public.varchar_ci DEFAULT '0'::character varying NOT NULL,
    CONSTRAINT phpbb_login_attempts_attempt_time_check CHECK ((attempt_time >= 0)),
    CONSTRAINT phpbb_login_attempts_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_migrations (
    migration_name character varying(255) DEFAULT ''::character varying NOT NULL,
    migration_depends_on character varying(8000) DEFAULT ''::character varying NOT NULL,
    migration_schema_done smallint DEFAULT '0'::smallint NOT NULL,
    migration_data_done smallint DEFAULT '0'::smallint NOT NULL,
    migration_data_state character varying(8000) DEFAULT ''::character varying NOT NULL,
    migration_start_time integer DEFAULT 0 NOT NULL,
    migration_end_time integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_migrations_migration_data_done_check CHECK ((migration_data_done >= 0)),
    CONSTRAINT phpbb_migrations_migration_end_time_check CHECK ((migration_end_time >= 0)),
    CONSTRAINT phpbb_migrations_migration_schema_done_check CHECK ((migration_schema_done >= 0)),
    CONSTRAINT phpbb_migrations_migration_start_time_check CHECK ((migration_start_time >= 0))
);


--
-- Name: phpbb_moderator_cache; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_moderator_cache (
    forum_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    username character varying(255) DEFAULT ''::character varying NOT NULL,
    group_id integer DEFAULT 0 NOT NULL,
    group_name character varying(255) DEFAULT ''::character varying NOT NULL,
    display_on_index smallint DEFAULT '1'::smallint NOT NULL,
    CONSTRAINT phpbb_moderator_cache_display_on_index_check CHECK ((display_on_index >= 0)),
    CONSTRAINT phpbb_moderator_cache_forum_id_check CHECK ((forum_id >= 0)),
    CONSTRAINT phpbb_moderator_cache_group_id_check CHECK ((group_id >= 0)),
    CONSTRAINT phpbb_moderator_cache_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_modules_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_modules_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_modules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_modules (
    module_id integer DEFAULT nextval('public.phpbb_modules_seq'::regclass) NOT NULL,
    module_enabled smallint DEFAULT '1'::smallint NOT NULL,
    module_display smallint DEFAULT '1'::smallint NOT NULL,
    module_basename character varying(255) DEFAULT ''::character varying NOT NULL,
    module_class character varying(10) DEFAULT ''::character varying NOT NULL,
    parent_id integer DEFAULT 0 NOT NULL,
    left_id integer DEFAULT 0 NOT NULL,
    right_id integer DEFAULT 0 NOT NULL,
    module_langname character varying(255) DEFAULT ''::character varying NOT NULL,
    module_mode character varying(255) DEFAULT ''::character varying NOT NULL,
    module_auth character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_modules_left_id_check CHECK ((left_id >= 0)),
    CONSTRAINT phpbb_modules_module_display_check CHECK ((module_display >= 0)),
    CONSTRAINT phpbb_modules_module_enabled_check CHECK ((module_enabled >= 0)),
    CONSTRAINT phpbb_modules_module_id_check CHECK ((module_id >= 0)),
    CONSTRAINT phpbb_modules_parent_id_check CHECK ((parent_id >= 0)),
    CONSTRAINT phpbb_modules_right_id_check CHECK ((right_id >= 0))
);


--
-- Name: phpbb_notification_types_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_notification_types_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_notification_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_notification_types (
    notification_type_id smallint DEFAULT nextval('public.phpbb_notification_types_seq'::regclass) NOT NULL,
    notification_type_name character varying(255) DEFAULT ''::character varying NOT NULL,
    notification_type_enabled smallint DEFAULT '1'::smallint NOT NULL,
    CONSTRAINT phpbb_notification_types_notification_type_enabled_check CHECK ((notification_type_enabled >= 0)),
    CONSTRAINT phpbb_notification_types_notification_type_id_check CHECK ((notification_type_id >= 0))
);


--
-- Name: phpbb_notifications_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_notifications_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_notifications (
    notification_id integer DEFAULT nextval('public.phpbb_notifications_seq'::regclass) NOT NULL,
    notification_type_id smallint DEFAULT '0'::smallint NOT NULL,
    item_id integer DEFAULT 0 NOT NULL,
    item_parent_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    notification_read smallint DEFAULT '0'::smallint NOT NULL,
    notification_time integer DEFAULT 1 NOT NULL,
    notification_data character varying(4000) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_notifications_item_id_check CHECK ((item_id >= 0)),
    CONSTRAINT phpbb_notifications_item_parent_id_check CHECK ((item_parent_id >= 0)),
    CONSTRAINT phpbb_notifications_notification_id_check CHECK ((notification_id >= 0)),
    CONSTRAINT phpbb_notifications_notification_read_check CHECK ((notification_read >= 0)),
    CONSTRAINT phpbb_notifications_notification_time_check CHECK ((notification_time >= 0)),
    CONSTRAINT phpbb_notifications_notification_type_id_check CHECK ((notification_type_id >= 0)),
    CONSTRAINT phpbb_notifications_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_oauth_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_oauth_accounts (
    user_id integer DEFAULT 0 NOT NULL,
    provider character varying(255) DEFAULT ''::character varying NOT NULL,
    oauth_provider_id character varying(4000) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_oauth_accounts_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_oauth_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_oauth_states (
    user_id integer DEFAULT 0 NOT NULL,
    session_id character(32) DEFAULT ''::bpchar NOT NULL,
    provider character varying(255) DEFAULT ''::character varying NOT NULL,
    oauth_state character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_oauth_states_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_oauth_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_oauth_tokens (
    user_id integer DEFAULT 0 NOT NULL,
    session_id character(32) DEFAULT ''::bpchar NOT NULL,
    provider character varying(255) DEFAULT ''::character varying NOT NULL,
    oauth_token text DEFAULT ''::text NOT NULL,
    CONSTRAINT phpbb_oauth_tokens_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_poll_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_poll_options (
    poll_option_id smallint DEFAULT '0'::smallint NOT NULL,
    topic_id integer DEFAULT 0 NOT NULL,
    poll_option_text character varying(4000) DEFAULT ''::character varying NOT NULL,
    poll_option_total integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_poll_options_poll_option_total_check CHECK ((poll_option_total >= 0)),
    CONSTRAINT phpbb_poll_options_topic_id_check CHECK ((topic_id >= 0))
);


--
-- Name: phpbb_poll_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_poll_votes (
    topic_id integer DEFAULT 0 NOT NULL,
    poll_option_id smallint DEFAULT '0'::smallint NOT NULL,
    vote_user_id integer DEFAULT 0 NOT NULL,
    vote_user_ip character varying(40) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_poll_votes_topic_id_check CHECK ((topic_id >= 0)),
    CONSTRAINT phpbb_poll_votes_vote_user_id_check CHECK ((vote_user_id >= 0))
);


--
-- Name: phpbb_posts_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_posts_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_posts (
    post_id integer DEFAULT nextval('public.phpbb_posts_seq'::regclass) NOT NULL,
    topic_id integer DEFAULT 0 NOT NULL,
    forum_id integer DEFAULT 0 NOT NULL,
    poster_id integer DEFAULT 0 NOT NULL,
    icon_id integer DEFAULT 0 NOT NULL,
    poster_ip character varying(40) DEFAULT ''::character varying NOT NULL,
    post_time integer DEFAULT 0 NOT NULL,
    post_reported smallint DEFAULT '0'::smallint NOT NULL,
    enable_bbcode smallint DEFAULT '1'::smallint NOT NULL,
    enable_smilies smallint DEFAULT '1'::smallint NOT NULL,
    enable_magic_url smallint DEFAULT '1'::smallint NOT NULL,
    enable_sig smallint DEFAULT '1'::smallint NOT NULL,
    post_username character varying(255) DEFAULT ''::character varying NOT NULL,
    post_subject character varying(255) DEFAULT ''::character varying NOT NULL,
    post_text text DEFAULT ''::text NOT NULL,
    post_checksum character varying(32) DEFAULT ''::character varying NOT NULL,
    post_attachment smallint DEFAULT '0'::smallint NOT NULL,
    bbcode_bitfield character varying(255) DEFAULT ''::character varying NOT NULL,
    bbcode_uid character varying(8) DEFAULT ''::character varying NOT NULL,
    post_postcount smallint DEFAULT '1'::smallint NOT NULL,
    post_edit_time integer DEFAULT 0 NOT NULL,
    post_edit_reason character varying(255) DEFAULT ''::character varying NOT NULL,
    post_edit_user integer DEFAULT 0 NOT NULL,
    post_edit_count smallint DEFAULT '0'::smallint NOT NULL,
    post_edit_locked smallint DEFAULT '0'::smallint NOT NULL,
    post_visibility smallint DEFAULT '0'::smallint NOT NULL,
    post_delete_time integer DEFAULT 0 NOT NULL,
    post_delete_reason character varying(255) DEFAULT ''::character varying NOT NULL,
    post_delete_user integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_posts_enable_bbcode_check CHECK ((enable_bbcode >= 0)),
    CONSTRAINT phpbb_posts_enable_magic_url_check CHECK ((enable_magic_url >= 0)),
    CONSTRAINT phpbb_posts_enable_sig_check CHECK ((enable_sig >= 0)),
    CONSTRAINT phpbb_posts_enable_smilies_check CHECK ((enable_smilies >= 0)),
    CONSTRAINT phpbb_posts_forum_id_check CHECK ((forum_id >= 0)),
    CONSTRAINT phpbb_posts_icon_id_check CHECK ((icon_id >= 0)),
    CONSTRAINT phpbb_posts_post_attachment_check CHECK ((post_attachment >= 0)),
    CONSTRAINT phpbb_posts_post_delete_time_check CHECK ((post_delete_time >= 0)),
    CONSTRAINT phpbb_posts_post_delete_user_check CHECK ((post_delete_user >= 0)),
    CONSTRAINT phpbb_posts_post_edit_count_check CHECK ((post_edit_count >= 0)),
    CONSTRAINT phpbb_posts_post_edit_locked_check CHECK ((post_edit_locked >= 0)),
    CONSTRAINT phpbb_posts_post_edit_time_check CHECK ((post_edit_time >= 0)),
    CONSTRAINT phpbb_posts_post_edit_user_check CHECK ((post_edit_user >= 0)),
    CONSTRAINT phpbb_posts_post_id_check CHECK ((post_id >= 0)),
    CONSTRAINT phpbb_posts_post_postcount_check CHECK ((post_postcount >= 0)),
    CONSTRAINT phpbb_posts_post_reported_check CHECK ((post_reported >= 0)),
    CONSTRAINT phpbb_posts_post_time_check CHECK ((post_time >= 0)),
    CONSTRAINT phpbb_posts_poster_id_check CHECK ((poster_id >= 0)),
    CONSTRAINT phpbb_posts_topic_id_check CHECK ((topic_id >= 0))
);


--
-- Name: phpbb_privmsgs_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_privmsgs_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_privmsgs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_privmsgs (
    msg_id integer DEFAULT nextval('public.phpbb_privmsgs_seq'::regclass) NOT NULL,
    root_level integer DEFAULT 0 NOT NULL,
    author_id integer DEFAULT 0 NOT NULL,
    icon_id integer DEFAULT 0 NOT NULL,
    author_ip character varying(40) DEFAULT ''::character varying NOT NULL,
    message_time integer DEFAULT 0 NOT NULL,
    enable_bbcode smallint DEFAULT '1'::smallint NOT NULL,
    enable_smilies smallint DEFAULT '1'::smallint NOT NULL,
    enable_magic_url smallint DEFAULT '1'::smallint NOT NULL,
    enable_sig smallint DEFAULT '1'::smallint NOT NULL,
    message_subject character varying(255) DEFAULT ''::character varying NOT NULL,
    message_text text DEFAULT ''::text NOT NULL,
    message_edit_reason character varying(255) DEFAULT ''::character varying NOT NULL,
    message_edit_user integer DEFAULT 0 NOT NULL,
    message_attachment smallint DEFAULT '0'::smallint NOT NULL,
    bbcode_bitfield character varying(255) DEFAULT ''::character varying NOT NULL,
    bbcode_uid character varying(8) DEFAULT ''::character varying NOT NULL,
    message_edit_time integer DEFAULT 0 NOT NULL,
    message_edit_count smallint DEFAULT '0'::smallint NOT NULL,
    to_address character varying(4000) DEFAULT ''::character varying NOT NULL,
    bcc_address character varying(4000) DEFAULT ''::character varying NOT NULL,
    message_reported smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_privmsgs_author_id_check CHECK ((author_id >= 0)),
    CONSTRAINT phpbb_privmsgs_enable_bbcode_check CHECK ((enable_bbcode >= 0)),
    CONSTRAINT phpbb_privmsgs_enable_magic_url_check CHECK ((enable_magic_url >= 0)),
    CONSTRAINT phpbb_privmsgs_enable_sig_check CHECK ((enable_sig >= 0)),
    CONSTRAINT phpbb_privmsgs_enable_smilies_check CHECK ((enable_smilies >= 0)),
    CONSTRAINT phpbb_privmsgs_icon_id_check CHECK ((icon_id >= 0)),
    CONSTRAINT phpbb_privmsgs_message_attachment_check CHECK ((message_attachment >= 0)),
    CONSTRAINT phpbb_privmsgs_message_edit_count_check CHECK ((message_edit_count >= 0)),
    CONSTRAINT phpbb_privmsgs_message_edit_time_check CHECK ((message_edit_time >= 0)),
    CONSTRAINT phpbb_privmsgs_message_edit_user_check CHECK ((message_edit_user >= 0)),
    CONSTRAINT phpbb_privmsgs_message_reported_check CHECK ((message_reported >= 0)),
    CONSTRAINT phpbb_privmsgs_message_time_check CHECK ((message_time >= 0)),
    CONSTRAINT phpbb_privmsgs_msg_id_check CHECK ((msg_id >= 0)),
    CONSTRAINT phpbb_privmsgs_root_level_check CHECK ((root_level >= 0))
);


--
-- Name: phpbb_privmsgs_folder_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_privmsgs_folder_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_privmsgs_folder; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_privmsgs_folder (
    folder_id integer DEFAULT nextval('public.phpbb_privmsgs_folder_seq'::regclass) NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    folder_name character varying(255) DEFAULT ''::character varying NOT NULL,
    pm_count integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_privmsgs_folder_folder_id_check CHECK ((folder_id >= 0)),
    CONSTRAINT phpbb_privmsgs_folder_pm_count_check CHECK ((pm_count >= 0)),
    CONSTRAINT phpbb_privmsgs_folder_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_privmsgs_rules_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_privmsgs_rules_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_privmsgs_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_privmsgs_rules (
    rule_id integer DEFAULT nextval('public.phpbb_privmsgs_rules_seq'::regclass) NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    rule_check integer DEFAULT 0 NOT NULL,
    rule_connection integer DEFAULT 0 NOT NULL,
    rule_string character varying(255) DEFAULT ''::character varying NOT NULL,
    rule_user_id integer DEFAULT 0 NOT NULL,
    rule_group_id integer DEFAULT 0 NOT NULL,
    rule_action integer DEFAULT 0 NOT NULL,
    rule_folder_id integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_privmsgs_rules_rule_action_check CHECK ((rule_action >= 0)),
    CONSTRAINT phpbb_privmsgs_rules_rule_check_check CHECK ((rule_check >= 0)),
    CONSTRAINT phpbb_privmsgs_rules_rule_connection_check CHECK ((rule_connection >= 0)),
    CONSTRAINT phpbb_privmsgs_rules_rule_group_id_check CHECK ((rule_group_id >= 0)),
    CONSTRAINT phpbb_privmsgs_rules_rule_id_check CHECK ((rule_id >= 0)),
    CONSTRAINT phpbb_privmsgs_rules_rule_user_id_check CHECK ((rule_user_id >= 0)),
    CONSTRAINT phpbb_privmsgs_rules_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_privmsgs_to; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_privmsgs_to (
    msg_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    author_id integer DEFAULT 0 NOT NULL,
    pm_deleted smallint DEFAULT '0'::smallint NOT NULL,
    pm_new smallint DEFAULT '1'::smallint NOT NULL,
    pm_unread smallint DEFAULT '1'::smallint NOT NULL,
    pm_replied smallint DEFAULT '0'::smallint NOT NULL,
    pm_marked smallint DEFAULT '0'::smallint NOT NULL,
    pm_forwarded smallint DEFAULT '0'::smallint NOT NULL,
    folder_id integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_privmsgs_to_author_id_check CHECK ((author_id >= 0)),
    CONSTRAINT phpbb_privmsgs_to_msg_id_check CHECK ((msg_id >= 0)),
    CONSTRAINT phpbb_privmsgs_to_pm_deleted_check CHECK ((pm_deleted >= 0)),
    CONSTRAINT phpbb_privmsgs_to_pm_forwarded_check CHECK ((pm_forwarded >= 0)),
    CONSTRAINT phpbb_privmsgs_to_pm_marked_check CHECK ((pm_marked >= 0)),
    CONSTRAINT phpbb_privmsgs_to_pm_new_check CHECK ((pm_new >= 0)),
    CONSTRAINT phpbb_privmsgs_to_pm_replied_check CHECK ((pm_replied >= 0)),
    CONSTRAINT phpbb_privmsgs_to_pm_unread_check CHECK ((pm_unread >= 0)),
    CONSTRAINT phpbb_privmsgs_to_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_profile_fields_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_profile_fields_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_profile_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_profile_fields (
    field_id integer DEFAULT nextval('public.phpbb_profile_fields_seq'::regclass) NOT NULL,
    field_name character varying(255) DEFAULT ''::character varying NOT NULL,
    field_type character varying(100) DEFAULT ''::character varying NOT NULL,
    field_ident character varying(20) DEFAULT ''::character varying NOT NULL,
    field_length character varying(20) DEFAULT ''::character varying NOT NULL,
    field_minlen character varying(255) DEFAULT ''::character varying NOT NULL,
    field_maxlen character varying(255) DEFAULT ''::character varying NOT NULL,
    field_novalue character varying(255) DEFAULT ''::character varying NOT NULL,
    field_default_value character varying(255) DEFAULT ''::character varying NOT NULL,
    field_validation character varying(64) DEFAULT ''::character varying NOT NULL,
    field_required smallint DEFAULT '0'::smallint NOT NULL,
    field_show_on_reg smallint DEFAULT '0'::smallint NOT NULL,
    field_hide smallint DEFAULT '0'::smallint NOT NULL,
    field_no_view smallint DEFAULT '0'::smallint NOT NULL,
    field_active smallint DEFAULT '0'::smallint NOT NULL,
    field_order integer DEFAULT 0 NOT NULL,
    field_show_profile smallint DEFAULT '0'::smallint NOT NULL,
    field_show_on_vt smallint DEFAULT '0'::smallint NOT NULL,
    field_show_novalue smallint DEFAULT '0'::smallint NOT NULL,
    field_show_on_pm smallint DEFAULT '0'::smallint NOT NULL,
    field_show_on_ml smallint DEFAULT '0'::smallint NOT NULL,
    field_is_contact smallint DEFAULT '0'::smallint NOT NULL,
    field_contact_desc character varying(255) DEFAULT ''::character varying NOT NULL,
    field_contact_url character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_profile_fields_field_active_check CHECK ((field_active >= 0)),
    CONSTRAINT phpbb_profile_fields_field_hide_check CHECK ((field_hide >= 0)),
    CONSTRAINT phpbb_profile_fields_field_id_check CHECK ((field_id >= 0)),
    CONSTRAINT phpbb_profile_fields_field_is_contact_check CHECK ((field_is_contact >= 0)),
    CONSTRAINT phpbb_profile_fields_field_no_view_check CHECK ((field_no_view >= 0)),
    CONSTRAINT phpbb_profile_fields_field_order_check CHECK ((field_order >= 0)),
    CONSTRAINT phpbb_profile_fields_field_required_check CHECK ((field_required >= 0)),
    CONSTRAINT phpbb_profile_fields_field_show_novalue_check CHECK ((field_show_novalue >= 0)),
    CONSTRAINT phpbb_profile_fields_field_show_on_ml_check CHECK ((field_show_on_ml >= 0)),
    CONSTRAINT phpbb_profile_fields_field_show_on_pm_check CHECK ((field_show_on_pm >= 0)),
    CONSTRAINT phpbb_profile_fields_field_show_on_reg_check CHECK ((field_show_on_reg >= 0)),
    CONSTRAINT phpbb_profile_fields_field_show_on_vt_check CHECK ((field_show_on_vt >= 0)),
    CONSTRAINT phpbb_profile_fields_field_show_profile_check CHECK ((field_show_profile >= 0))
);


--
-- Name: phpbb_profile_fields_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_profile_fields_data (
    user_id integer DEFAULT 0 NOT NULL,
    pf_phpbb_interests text DEFAULT ''::text NOT NULL,
    pf_phpbb_occupation text DEFAULT ''::text NOT NULL,
    pf_phpbb_facebook character varying(255) DEFAULT ''::character varying NOT NULL,
    pf_phpbb_googleplus character varying(255) DEFAULT ''::character varying NOT NULL,
    pf_phpbb_icq character varying(255) DEFAULT ''::character varying NOT NULL,
    pf_phpbb_location character varying(255) DEFAULT ''::character varying NOT NULL,
    pf_phpbb_skype character varying(255) DEFAULT ''::character varying NOT NULL,
    pf_phpbb_twitter character varying(255) DEFAULT ''::character varying NOT NULL,
    pf_phpbb_website character varying(255) DEFAULT ''::character varying NOT NULL,
    pf_phpbb_yahoo character varying(255) DEFAULT ''::character varying NOT NULL,
    pf_phpbb_youtube character varying(255) DEFAULT ''::character varying NOT NULL,
    pf_phpbb_aol character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_profile_fields_data_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_profile_fields_lang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_profile_fields_lang (
    field_id integer DEFAULT 0 NOT NULL,
    lang_id integer DEFAULT 0 NOT NULL,
    option_id integer DEFAULT 0 NOT NULL,
    field_type character varying(100) DEFAULT ''::character varying NOT NULL,
    lang_value character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_profile_fields_lang_field_id_check CHECK ((field_id >= 0)),
    CONSTRAINT phpbb_profile_fields_lang_lang_id_check CHECK ((lang_id >= 0)),
    CONSTRAINT phpbb_profile_fields_lang_option_id_check CHECK ((option_id >= 0))
);


--
-- Name: phpbb_profile_lang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_profile_lang (
    field_id integer DEFAULT 0 NOT NULL,
    lang_id integer DEFAULT 0 NOT NULL,
    lang_name character varying(255) DEFAULT ''::character varying NOT NULL,
    lang_explain character varying(4000) DEFAULT ''::character varying NOT NULL,
    lang_default_value character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_profile_lang_field_id_check CHECK ((field_id >= 0)),
    CONSTRAINT phpbb_profile_lang_lang_id_check CHECK ((lang_id >= 0))
);


--
-- Name: phpbb_ranks_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_ranks_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_ranks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_ranks (
    rank_id integer DEFAULT nextval('public.phpbb_ranks_seq'::regclass) NOT NULL,
    rank_title character varying(255) DEFAULT ''::character varying NOT NULL,
    rank_min integer DEFAULT 0 NOT NULL,
    rank_special smallint DEFAULT '0'::smallint NOT NULL,
    rank_image character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_ranks_rank_id_check CHECK ((rank_id >= 0)),
    CONSTRAINT phpbb_ranks_rank_min_check CHECK ((rank_min >= 0)),
    CONSTRAINT phpbb_ranks_rank_special_check CHECK ((rank_special >= 0))
);


--
-- Name: phpbb_reports_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_reports_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_reports (
    report_id integer DEFAULT nextval('public.phpbb_reports_seq'::regclass) NOT NULL,
    reason_id smallint DEFAULT '0'::smallint NOT NULL,
    post_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    user_notify smallint DEFAULT '0'::smallint NOT NULL,
    report_closed smallint DEFAULT '0'::smallint NOT NULL,
    report_time integer DEFAULT 0 NOT NULL,
    report_text text DEFAULT ''::text NOT NULL,
    pm_id integer DEFAULT 0 NOT NULL,
    reported_post_enable_bbcode smallint DEFAULT '1'::smallint NOT NULL,
    reported_post_enable_smilies smallint DEFAULT '1'::smallint NOT NULL,
    reported_post_enable_magic_url smallint DEFAULT '1'::smallint NOT NULL,
    reported_post_text text DEFAULT ''::text NOT NULL,
    reported_post_uid character varying(8) DEFAULT ''::character varying NOT NULL,
    reported_post_bitfield character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_reports_pm_id_check CHECK ((pm_id >= 0)),
    CONSTRAINT phpbb_reports_post_id_check CHECK ((post_id >= 0)),
    CONSTRAINT phpbb_reports_reason_id_check CHECK ((reason_id >= 0)),
    CONSTRAINT phpbb_reports_report_closed_check CHECK ((report_closed >= 0)),
    CONSTRAINT phpbb_reports_report_id_check CHECK ((report_id >= 0)),
    CONSTRAINT phpbb_reports_report_time_check CHECK ((report_time >= 0)),
    CONSTRAINT phpbb_reports_reported_post_enable_bbcode_check CHECK ((reported_post_enable_bbcode >= 0)),
    CONSTRAINT phpbb_reports_reported_post_enable_magic_url_check CHECK ((reported_post_enable_magic_url >= 0)),
    CONSTRAINT phpbb_reports_reported_post_enable_smilies_check CHECK ((reported_post_enable_smilies >= 0)),
    CONSTRAINT phpbb_reports_user_id_check CHECK ((user_id >= 0)),
    CONSTRAINT phpbb_reports_user_notify_check CHECK ((user_notify >= 0))
);


--
-- Name: phpbb_reports_reasons_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_reports_reasons_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_reports_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_reports_reasons (
    reason_id smallint DEFAULT nextval('public.phpbb_reports_reasons_seq'::regclass) NOT NULL,
    reason_title character varying(255) DEFAULT ''::character varying NOT NULL,
    reason_description text DEFAULT ''::text NOT NULL,
    reason_order smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_reports_reasons_reason_id_check CHECK ((reason_id >= 0)),
    CONSTRAINT phpbb_reports_reasons_reason_order_check CHECK ((reason_order >= 0))
);


--
-- Name: phpbb_search_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_search_results (
    search_key character varying(32) DEFAULT ''::character varying NOT NULL,
    search_time integer DEFAULT 0 NOT NULL,
    search_keywords text DEFAULT ''::text NOT NULL,
    search_authors text DEFAULT ''::text NOT NULL,
    CONSTRAINT phpbb_search_results_search_time_check CHECK ((search_time >= 0))
);


--
-- Name: phpbb_search_wordlist_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_search_wordlist_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_search_wordlist; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_search_wordlist (
    word_id integer DEFAULT nextval('public.phpbb_search_wordlist_seq'::regclass) NOT NULL,
    word_text character varying(255) DEFAULT ''::character varying NOT NULL,
    word_common smallint DEFAULT '0'::smallint NOT NULL,
    word_count integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_search_wordlist_word_common_check CHECK ((word_common >= 0)),
    CONSTRAINT phpbb_search_wordlist_word_count_check CHECK ((word_count >= 0)),
    CONSTRAINT phpbb_search_wordlist_word_id_check CHECK ((word_id >= 0))
);


--
-- Name: phpbb_search_wordmatch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_search_wordmatch (
    post_id integer DEFAULT 0 NOT NULL,
    word_id integer DEFAULT 0 NOT NULL,
    title_match smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_search_wordmatch_post_id_check CHECK ((post_id >= 0)),
    CONSTRAINT phpbb_search_wordmatch_title_match_check CHECK ((title_match >= 0)),
    CONSTRAINT phpbb_search_wordmatch_word_id_check CHECK ((word_id >= 0))
);


--
-- Name: phpbb_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_sessions (
    session_id character(32) DEFAULT ''::bpchar NOT NULL,
    session_user_id integer DEFAULT 0 NOT NULL,
    session_last_visit integer DEFAULT 0 NOT NULL,
    session_start integer DEFAULT 0 NOT NULL,
    session_time integer DEFAULT 0 NOT NULL,
    session_ip character varying(40) DEFAULT ''::character varying NOT NULL,
    session_browser character varying(150) DEFAULT ''::character varying NOT NULL,
    session_forwarded_for character varying(255) DEFAULT ''::character varying NOT NULL,
    session_page character varying(255) DEFAULT ''::character varying NOT NULL,
    session_viewonline smallint DEFAULT '1'::smallint NOT NULL,
    session_autologin smallint DEFAULT '0'::smallint NOT NULL,
    session_admin smallint DEFAULT '0'::smallint NOT NULL,
    session_forum_id integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_sessions_session_admin_check CHECK ((session_admin >= 0)),
    CONSTRAINT phpbb_sessions_session_autologin_check CHECK ((session_autologin >= 0)),
    CONSTRAINT phpbb_sessions_session_forum_id_check CHECK ((session_forum_id >= 0)),
    CONSTRAINT phpbb_sessions_session_last_visit_check CHECK ((session_last_visit >= 0)),
    CONSTRAINT phpbb_sessions_session_start_check CHECK ((session_start >= 0)),
    CONSTRAINT phpbb_sessions_session_time_check CHECK ((session_time >= 0)),
    CONSTRAINT phpbb_sessions_session_user_id_check CHECK ((session_user_id >= 0)),
    CONSTRAINT phpbb_sessions_session_viewonline_check CHECK ((session_viewonline >= 0))
);


--
-- Name: phpbb_sessions_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_sessions_keys (
    key_id character(32) DEFAULT ''::bpchar NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    last_ip character varying(40) DEFAULT ''::character varying NOT NULL,
    last_login integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_sessions_keys_last_login_check CHECK ((last_login >= 0)),
    CONSTRAINT phpbb_sessions_keys_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_sitelist_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_sitelist_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_sitelist; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_sitelist (
    site_id integer DEFAULT nextval('public.phpbb_sitelist_seq'::regclass) NOT NULL,
    site_ip character varying(40) DEFAULT ''::character varying NOT NULL,
    site_hostname character varying(255) DEFAULT ''::character varying NOT NULL,
    ip_exclude smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_sitelist_ip_exclude_check CHECK ((ip_exclude >= 0)),
    CONSTRAINT phpbb_sitelist_site_id_check CHECK ((site_id >= 0))
);


--
-- Name: phpbb_smilies_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_smilies_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_smilies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_smilies (
    smiley_id integer DEFAULT nextval('public.phpbb_smilies_seq'::regclass) NOT NULL,
    code character varying(50) DEFAULT ''::character varying NOT NULL,
    emotion character varying(255) DEFAULT ''::character varying NOT NULL,
    smiley_url character varying(50) DEFAULT ''::character varying NOT NULL,
    smiley_width smallint DEFAULT '0'::smallint NOT NULL,
    smiley_height smallint DEFAULT '0'::smallint NOT NULL,
    smiley_order integer DEFAULT 0 NOT NULL,
    display_on_posting smallint DEFAULT '1'::smallint NOT NULL,
    CONSTRAINT phpbb_smilies_display_on_posting_check CHECK ((display_on_posting >= 0)),
    CONSTRAINT phpbb_smilies_smiley_height_check CHECK ((smiley_height >= 0)),
    CONSTRAINT phpbb_smilies_smiley_id_check CHECK ((smiley_id >= 0)),
    CONSTRAINT phpbb_smilies_smiley_order_check CHECK ((smiley_order >= 0)),
    CONSTRAINT phpbb_smilies_smiley_width_check CHECK ((smiley_width >= 0))
);


--
-- Name: phpbb_styles_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_styles_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_styles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_styles (
    style_id integer DEFAULT nextval('public.phpbb_styles_seq'::regclass) NOT NULL,
    style_name character varying(255) DEFAULT ''::character varying NOT NULL,
    style_copyright character varying(255) DEFAULT ''::character varying NOT NULL,
    style_active smallint DEFAULT '1'::smallint NOT NULL,
    style_path character varying(100) DEFAULT ''::character varying NOT NULL,
    bbcode_bitfield character varying(255) DEFAULT 'kNg='::character varying NOT NULL,
    style_parent_id integer DEFAULT 0 NOT NULL,
    style_parent_tree character varying(8000) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_styles_style_active_check CHECK ((style_active >= 0)),
    CONSTRAINT phpbb_styles_style_id_check CHECK ((style_id >= 0)),
    CONSTRAINT phpbb_styles_style_parent_id_check CHECK ((style_parent_id >= 0))
);


--
-- Name: phpbb_teampage_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_teampage_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_teampage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_teampage (
    teampage_id integer DEFAULT nextval('public.phpbb_teampage_seq'::regclass) NOT NULL,
    group_id integer DEFAULT 0 NOT NULL,
    teampage_name character varying(255) DEFAULT ''::character varying NOT NULL,
    teampage_position integer DEFAULT 0 NOT NULL,
    teampage_parent integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_teampage_group_id_check CHECK ((group_id >= 0)),
    CONSTRAINT phpbb_teampage_teampage_id_check CHECK ((teampage_id >= 0)),
    CONSTRAINT phpbb_teampage_teampage_parent_check CHECK ((teampage_parent >= 0)),
    CONSTRAINT phpbb_teampage_teampage_position_check CHECK ((teampage_position >= 0))
);


--
-- Name: phpbb_topics_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_topics_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_topics (
    topic_id integer DEFAULT nextval('public.phpbb_topics_seq'::regclass) NOT NULL,
    forum_id integer DEFAULT 0 NOT NULL,
    icon_id integer DEFAULT 0 NOT NULL,
    topic_attachment smallint DEFAULT '0'::smallint NOT NULL,
    topic_reported smallint DEFAULT '0'::smallint NOT NULL,
    topic_title character varying(255) DEFAULT ''::character varying NOT NULL,
    topic_poster integer DEFAULT 0 NOT NULL,
    topic_time integer DEFAULT 0 NOT NULL,
    topic_time_limit integer DEFAULT 0 NOT NULL,
    topic_views integer DEFAULT 0 NOT NULL,
    topic_status smallint DEFAULT '0'::smallint NOT NULL,
    topic_type smallint DEFAULT '0'::smallint NOT NULL,
    topic_first_post_id integer DEFAULT 0 NOT NULL,
    topic_first_poster_name character varying(255) DEFAULT ''::character varying NOT NULL,
    topic_first_poster_colour character varying(6) DEFAULT ''::character varying NOT NULL,
    topic_last_post_id integer DEFAULT 0 NOT NULL,
    topic_last_poster_id integer DEFAULT 0 NOT NULL,
    topic_last_poster_name character varying(255) DEFAULT ''::character varying NOT NULL,
    topic_last_poster_colour character varying(6) DEFAULT ''::character varying NOT NULL,
    topic_last_post_subject character varying(255) DEFAULT ''::character varying NOT NULL,
    topic_last_post_time integer DEFAULT 0 NOT NULL,
    topic_last_view_time integer DEFAULT 0 NOT NULL,
    topic_moved_id integer DEFAULT 0 NOT NULL,
    topic_bumped smallint DEFAULT '0'::smallint NOT NULL,
    topic_bumper integer DEFAULT 0 NOT NULL,
    poll_title character varying(255) DEFAULT ''::character varying NOT NULL,
    poll_start integer DEFAULT 0 NOT NULL,
    poll_length integer DEFAULT 0 NOT NULL,
    poll_max_options smallint DEFAULT '1'::smallint NOT NULL,
    poll_last_vote integer DEFAULT 0 NOT NULL,
    poll_vote_change smallint DEFAULT '0'::smallint NOT NULL,
    topic_visibility smallint DEFAULT '0'::smallint NOT NULL,
    topic_delete_time integer DEFAULT 0 NOT NULL,
    topic_delete_reason character varying(255) DEFAULT ''::character varying NOT NULL,
    topic_delete_user integer DEFAULT 0 NOT NULL,
    topic_posts_approved integer DEFAULT 0 NOT NULL,
    topic_posts_unapproved integer DEFAULT 0 NOT NULL,
    topic_posts_softdeleted integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_topics_forum_id_check CHECK ((forum_id >= 0)),
    CONSTRAINT phpbb_topics_icon_id_check CHECK ((icon_id >= 0)),
    CONSTRAINT phpbb_topics_poll_last_vote_check CHECK ((poll_last_vote >= 0)),
    CONSTRAINT phpbb_topics_poll_length_check CHECK ((poll_length >= 0)),
    CONSTRAINT phpbb_topics_poll_start_check CHECK ((poll_start >= 0)),
    CONSTRAINT phpbb_topics_poll_vote_change_check CHECK ((poll_vote_change >= 0)),
    CONSTRAINT phpbb_topics_topic_attachment_check CHECK ((topic_attachment >= 0)),
    CONSTRAINT phpbb_topics_topic_bumped_check CHECK ((topic_bumped >= 0)),
    CONSTRAINT phpbb_topics_topic_bumper_check CHECK ((topic_bumper >= 0)),
    CONSTRAINT phpbb_topics_topic_delete_time_check CHECK ((topic_delete_time >= 0)),
    CONSTRAINT phpbb_topics_topic_delete_user_check CHECK ((topic_delete_user >= 0)),
    CONSTRAINT phpbb_topics_topic_first_post_id_check CHECK ((topic_first_post_id >= 0)),
    CONSTRAINT phpbb_topics_topic_id_check CHECK ((topic_id >= 0)),
    CONSTRAINT phpbb_topics_topic_last_post_id_check CHECK ((topic_last_post_id >= 0)),
    CONSTRAINT phpbb_topics_topic_last_post_time_check CHECK ((topic_last_post_time >= 0)),
    CONSTRAINT phpbb_topics_topic_last_poster_id_check CHECK ((topic_last_poster_id >= 0)),
    CONSTRAINT phpbb_topics_topic_last_view_time_check CHECK ((topic_last_view_time >= 0)),
    CONSTRAINT phpbb_topics_topic_moved_id_check CHECK ((topic_moved_id >= 0)),
    CONSTRAINT phpbb_topics_topic_poster_check CHECK ((topic_poster >= 0)),
    CONSTRAINT phpbb_topics_topic_posts_approved_check CHECK ((topic_posts_approved >= 0)),
    CONSTRAINT phpbb_topics_topic_posts_softdeleted_check CHECK ((topic_posts_softdeleted >= 0)),
    CONSTRAINT phpbb_topics_topic_posts_unapproved_check CHECK ((topic_posts_unapproved >= 0)),
    CONSTRAINT phpbb_topics_topic_reported_check CHECK ((topic_reported >= 0)),
    CONSTRAINT phpbb_topics_topic_time_check CHECK ((topic_time >= 0)),
    CONSTRAINT phpbb_topics_topic_time_limit_check CHECK ((topic_time_limit >= 0)),
    CONSTRAINT phpbb_topics_topic_views_check CHECK ((topic_views >= 0))
);


--
-- Name: phpbb_topics_posted; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_topics_posted (
    user_id integer DEFAULT 0 NOT NULL,
    topic_id integer DEFAULT 0 NOT NULL,
    topic_posted smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_topics_posted_topic_id_check CHECK ((topic_id >= 0)),
    CONSTRAINT phpbb_topics_posted_topic_posted_check CHECK ((topic_posted >= 0)),
    CONSTRAINT phpbb_topics_posted_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_topics_track; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_topics_track (
    user_id integer DEFAULT 0 NOT NULL,
    topic_id integer DEFAULT 0 NOT NULL,
    forum_id integer DEFAULT 0 NOT NULL,
    mark_time integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_topics_track_forum_id_check CHECK ((forum_id >= 0)),
    CONSTRAINT phpbb_topics_track_mark_time_check CHECK ((mark_time >= 0)),
    CONSTRAINT phpbb_topics_track_topic_id_check CHECK ((topic_id >= 0)),
    CONSTRAINT phpbb_topics_track_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_topics_watch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_topics_watch (
    topic_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    notify_status smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_topics_watch_notify_status_check CHECK ((notify_status >= 0)),
    CONSTRAINT phpbb_topics_watch_topic_id_check CHECK ((topic_id >= 0)),
    CONSTRAINT phpbb_topics_watch_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_user_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_user_group (
    group_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    group_leader smallint DEFAULT '0'::smallint NOT NULL,
    user_pending smallint DEFAULT '1'::smallint NOT NULL,
    CONSTRAINT phpbb_user_group_group_id_check CHECK ((group_id >= 0)),
    CONSTRAINT phpbb_user_group_group_leader_check CHECK ((group_leader >= 0)),
    CONSTRAINT phpbb_user_group_user_id_check CHECK ((user_id >= 0)),
    CONSTRAINT phpbb_user_group_user_pending_check CHECK ((user_pending >= 0))
);


--
-- Name: phpbb_user_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_user_notifications (
    item_type character varying(165) DEFAULT ''::character varying NOT NULL,
    item_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    method character varying(165) DEFAULT ''::character varying NOT NULL,
    notify smallint DEFAULT '1'::smallint NOT NULL,
    CONSTRAINT phpbb_user_notifications_item_id_check CHECK ((item_id >= 0)),
    CONSTRAINT phpbb_user_notifications_notify_check CHECK ((notify >= 0)),
    CONSTRAINT phpbb_user_notifications_user_id_check CHECK ((user_id >= 0))
);


--
-- Name: phpbb_users_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_users_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_users (
    user_id integer DEFAULT nextval('public.phpbb_users_seq'::regclass) NOT NULL,
    user_type smallint DEFAULT '0'::smallint NOT NULL,
    group_id integer DEFAULT 3 NOT NULL,
    user_permissions text DEFAULT ''::text NOT NULL,
    user_perm_from integer DEFAULT 0 NOT NULL,
    user_ip character varying(40) DEFAULT ''::character varying NOT NULL,
    user_regdate integer DEFAULT 0 NOT NULL,
    username public.varchar_ci DEFAULT ''::character varying NOT NULL,
    username_clean public.varchar_ci DEFAULT ''::character varying NOT NULL,
    user_password character varying(255) DEFAULT ''::character varying NOT NULL,
    user_passchg integer DEFAULT 0 NOT NULL,
    user_email character varying(100) DEFAULT ''::character varying NOT NULL,
    user_email_hash bigint DEFAULT '0'::bigint NOT NULL,
    user_birthday character varying(10) DEFAULT ''::character varying NOT NULL,
    user_lastvisit integer DEFAULT 0 NOT NULL,
    user_lastmark integer DEFAULT 0 NOT NULL,
    user_lastpost_time integer DEFAULT 0 NOT NULL,
    user_lastpage character varying(200) DEFAULT ''::character varying NOT NULL,
    user_last_confirm_key character varying(10) DEFAULT ''::character varying NOT NULL,
    user_last_search integer DEFAULT 0 NOT NULL,
    user_warnings smallint DEFAULT '0'::smallint NOT NULL,
    user_last_warning integer DEFAULT 0 NOT NULL,
    user_login_attempts smallint DEFAULT '0'::smallint NOT NULL,
    user_inactive_reason smallint DEFAULT '0'::smallint NOT NULL,
    user_inactive_time integer DEFAULT 0 NOT NULL,
    user_posts integer DEFAULT 0 NOT NULL,
    user_lang character varying(30) DEFAULT ''::character varying NOT NULL,
    user_timezone character varying(100) DEFAULT ''::character varying NOT NULL,
    user_dateformat character varying(64) DEFAULT 'd M Y H:i'::character varying NOT NULL,
    user_style integer DEFAULT 0 NOT NULL,
    user_rank integer DEFAULT 0 NOT NULL,
    user_colour character varying(6) DEFAULT ''::character varying NOT NULL,
    user_new_privmsg integer DEFAULT 0 NOT NULL,
    user_unread_privmsg integer DEFAULT 0 NOT NULL,
    user_last_privmsg integer DEFAULT 0 NOT NULL,
    user_message_rules smallint DEFAULT '0'::smallint NOT NULL,
    user_full_folder integer DEFAULT '-3'::integer NOT NULL,
    user_emailtime integer DEFAULT 0 NOT NULL,
    user_topic_show_days smallint DEFAULT '0'::smallint NOT NULL,
    user_topic_sortby_type character varying(1) DEFAULT 't'::character varying NOT NULL,
    user_topic_sortby_dir character varying(1) DEFAULT 'd'::character varying NOT NULL,
    user_post_show_days smallint DEFAULT '0'::smallint NOT NULL,
    user_post_sortby_type character varying(1) DEFAULT 't'::character varying NOT NULL,
    user_post_sortby_dir character varying(1) DEFAULT 'a'::character varying NOT NULL,
    user_notify smallint DEFAULT '0'::smallint NOT NULL,
    user_notify_pm smallint DEFAULT '1'::smallint NOT NULL,
    user_notify_type smallint DEFAULT '0'::smallint NOT NULL,
    user_allow_pm smallint DEFAULT '1'::smallint NOT NULL,
    user_allow_viewonline smallint DEFAULT '1'::smallint NOT NULL,
    user_allow_viewemail smallint DEFAULT '1'::smallint NOT NULL,
    user_allow_massemail smallint DEFAULT '1'::smallint NOT NULL,
    user_options integer DEFAULT 230271 NOT NULL,
    user_avatar character varying(255) DEFAULT ''::character varying NOT NULL,
    user_avatar_type character varying(255) DEFAULT ''::character varying NOT NULL,
    user_avatar_width smallint DEFAULT '0'::smallint NOT NULL,
    user_avatar_height smallint DEFAULT '0'::smallint NOT NULL,
    user_sig text DEFAULT ''::text NOT NULL,
    user_sig_bbcode_uid character varying(8) DEFAULT ''::character varying NOT NULL,
    user_sig_bbcode_bitfield character varying(255) DEFAULT ''::character varying NOT NULL,
    user_jabber character varying(255) DEFAULT ''::character varying NOT NULL,
    user_actkey character varying(32) DEFAULT ''::character varying NOT NULL,
    user_newpasswd character varying(255) DEFAULT ''::character varying NOT NULL,
    user_form_salt character varying(32) DEFAULT ''::character varying NOT NULL,
    user_new smallint DEFAULT '1'::smallint NOT NULL,
    user_reminded smallint DEFAULT '0'::smallint NOT NULL,
    user_reminded_time integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_users_group_id_check CHECK ((group_id >= 0)),
    CONSTRAINT phpbb_users_user_allow_massemail_check CHECK ((user_allow_massemail >= 0)),
    CONSTRAINT phpbb_users_user_allow_pm_check CHECK ((user_allow_pm >= 0)),
    CONSTRAINT phpbb_users_user_allow_viewemail_check CHECK ((user_allow_viewemail >= 0)),
    CONSTRAINT phpbb_users_user_allow_viewonline_check CHECK ((user_allow_viewonline >= 0)),
    CONSTRAINT phpbb_users_user_avatar_height_check CHECK ((user_avatar_height >= 0)),
    CONSTRAINT phpbb_users_user_avatar_width_check CHECK ((user_avatar_width >= 0)),
    CONSTRAINT phpbb_users_user_emailtime_check CHECK ((user_emailtime >= 0)),
    CONSTRAINT phpbb_users_user_id_check CHECK ((user_id >= 0)),
    CONSTRAINT phpbb_users_user_inactive_time_check CHECK ((user_inactive_time >= 0)),
    CONSTRAINT phpbb_users_user_last_privmsg_check CHECK ((user_last_privmsg >= 0)),
    CONSTRAINT phpbb_users_user_last_search_check CHECK ((user_last_search >= 0)),
    CONSTRAINT phpbb_users_user_last_warning_check CHECK ((user_last_warning >= 0)),
    CONSTRAINT phpbb_users_user_lastmark_check CHECK ((user_lastmark >= 0)),
    CONSTRAINT phpbb_users_user_lastpost_time_check CHECK ((user_lastpost_time >= 0)),
    CONSTRAINT phpbb_users_user_lastvisit_check CHECK ((user_lastvisit >= 0)),
    CONSTRAINT phpbb_users_user_message_rules_check CHECK ((user_message_rules >= 0)),
    CONSTRAINT phpbb_users_user_new_check CHECK ((user_new >= 0)),
    CONSTRAINT phpbb_users_user_notify_check CHECK ((user_notify >= 0)),
    CONSTRAINT phpbb_users_user_notify_pm_check CHECK ((user_notify_pm >= 0)),
    CONSTRAINT phpbb_users_user_options_check CHECK ((user_options >= 0)),
    CONSTRAINT phpbb_users_user_passchg_check CHECK ((user_passchg >= 0)),
    CONSTRAINT phpbb_users_user_perm_from_check CHECK ((user_perm_from >= 0)),
    CONSTRAINT phpbb_users_user_post_show_days_check CHECK ((user_post_show_days >= 0)),
    CONSTRAINT phpbb_users_user_posts_check CHECK ((user_posts >= 0)),
    CONSTRAINT phpbb_users_user_rank_check CHECK ((user_rank >= 0)),
    CONSTRAINT phpbb_users_user_regdate_check CHECK ((user_regdate >= 0)),
    CONSTRAINT phpbb_users_user_reminded_time_check CHECK ((user_reminded_time >= 0)),
    CONSTRAINT phpbb_users_user_style_check CHECK ((user_style >= 0)),
    CONSTRAINT phpbb_users_user_topic_show_days_check CHECK ((user_topic_show_days >= 0))
);


--
-- Name: phpbb_warnings_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_warnings_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_warnings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_warnings (
    warning_id integer DEFAULT nextval('public.phpbb_warnings_seq'::regclass) NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    post_id integer DEFAULT 0 NOT NULL,
    log_id integer DEFAULT 0 NOT NULL,
    warning_time integer DEFAULT 0 NOT NULL,
    CONSTRAINT phpbb_warnings_log_id_check CHECK ((log_id >= 0)),
    CONSTRAINT phpbb_warnings_post_id_check CHECK ((post_id >= 0)),
    CONSTRAINT phpbb_warnings_user_id_check CHECK ((user_id >= 0)),
    CONSTRAINT phpbb_warnings_warning_id_check CHECK ((warning_id >= 0)),
    CONSTRAINT phpbb_warnings_warning_time_check CHECK ((warning_time >= 0))
);


--
-- Name: phpbb_words_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phpbb_words_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phpbb_words; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_words (
    word_id integer DEFAULT nextval('public.phpbb_words_seq'::regclass) NOT NULL,
    word character varying(255) DEFAULT ''::character varying NOT NULL,
    replacement character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT phpbb_words_word_id_check CHECK ((word_id >= 0))
);


--
-- Name: phpbb_zebra; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phpbb_zebra (
    user_id integer DEFAULT 0 NOT NULL,
    zebra_id integer DEFAULT 0 NOT NULL,
    friend smallint DEFAULT '0'::smallint NOT NULL,
    foe smallint DEFAULT '0'::smallint NOT NULL,
    CONSTRAINT phpbb_zebra_foe_check CHECK ((foe >= 0)),
    CONSTRAINT phpbb_zebra_friend_check CHECK ((friend >= 0)),
    CONSTRAINT phpbb_zebra_user_id_check CHECK ((user_id >= 0)),
    CONSTRAINT phpbb_zebra_zebra_id_check CHECK ((zebra_id >= 0))
);


--
-- Name: phpbb_acl_options phpbb_acl_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_acl_options
    ADD CONSTRAINT phpbb_acl_options_pkey PRIMARY KEY (auth_option_id);


--
-- Name: phpbb_acl_roles_data phpbb_acl_roles_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_acl_roles_data
    ADD CONSTRAINT phpbb_acl_roles_data_pkey PRIMARY KEY (role_id, auth_option_id);


--
-- Name: phpbb_acl_roles phpbb_acl_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_acl_roles
    ADD CONSTRAINT phpbb_acl_roles_pkey PRIMARY KEY (role_id);


--
-- Name: phpbb_attachments phpbb_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_attachments
    ADD CONSTRAINT phpbb_attachments_pkey PRIMARY KEY (attach_id);


--
-- Name: phpbb_banlist phpbb_banlist_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_banlist
    ADD CONSTRAINT phpbb_banlist_pkey PRIMARY KEY (ban_id);


--
-- Name: phpbb_bbcodes phpbb_bbcodes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_bbcodes
    ADD CONSTRAINT phpbb_bbcodes_pkey PRIMARY KEY (bbcode_id);


--
-- Name: phpbb_bookmarks phpbb_bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_bookmarks
    ADD CONSTRAINT phpbb_bookmarks_pkey PRIMARY KEY (topic_id, user_id);


--
-- Name: phpbb_bots phpbb_bots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_bots
    ADD CONSTRAINT phpbb_bots_pkey PRIMARY KEY (bot_id);


--
-- Name: phpbb_config phpbb_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_config
    ADD CONSTRAINT phpbb_config_pkey PRIMARY KEY (config_name);


--
-- Name: phpbb_config_text phpbb_config_text_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_config_text
    ADD CONSTRAINT phpbb_config_text_pkey PRIMARY KEY (config_name);


--
-- Name: phpbb_confirm phpbb_confirm_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_confirm
    ADD CONSTRAINT phpbb_confirm_pkey PRIMARY KEY (session_id, confirm_id);


--
-- Name: phpbb_disallow phpbb_disallow_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_disallow
    ADD CONSTRAINT phpbb_disallow_pkey PRIMARY KEY (disallow_id);


--
-- Name: phpbb_drafts phpbb_drafts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_drafts
    ADD CONSTRAINT phpbb_drafts_pkey PRIMARY KEY (draft_id);


--
-- Name: phpbb_extension_groups phpbb_extension_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_extension_groups
    ADD CONSTRAINT phpbb_extension_groups_pkey PRIMARY KEY (group_id);


--
-- Name: phpbb_extensions phpbb_extensions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_extensions
    ADD CONSTRAINT phpbb_extensions_pkey PRIMARY KEY (extension_id);


--
-- Name: phpbb_forums_access phpbb_forums_access_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_forums_access
    ADD CONSTRAINT phpbb_forums_access_pkey PRIMARY KEY (forum_id, user_id, session_id);


--
-- Name: phpbb_forums phpbb_forums_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_forums
    ADD CONSTRAINT phpbb_forums_pkey PRIMARY KEY (forum_id);


--
-- Name: phpbb_forums_track phpbb_forums_track_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_forums_track
    ADD CONSTRAINT phpbb_forums_track_pkey PRIMARY KEY (user_id, forum_id);


--
-- Name: phpbb_groups phpbb_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_groups
    ADD CONSTRAINT phpbb_groups_pkey PRIMARY KEY (group_id);


--
-- Name: phpbb_icons phpbb_icons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_icons
    ADD CONSTRAINT phpbb_icons_pkey PRIMARY KEY (icons_id);


--
-- Name: phpbb_lang phpbb_lang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_lang
    ADD CONSTRAINT phpbb_lang_pkey PRIMARY KEY (lang_id);


--
-- Name: phpbb_log phpbb_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_log
    ADD CONSTRAINT phpbb_log_pkey PRIMARY KEY (log_id);


--
-- Name: phpbb_migrations phpbb_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_migrations
    ADD CONSTRAINT phpbb_migrations_pkey PRIMARY KEY (migration_name);


--
-- Name: phpbb_modules phpbb_modules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_modules
    ADD CONSTRAINT phpbb_modules_pkey PRIMARY KEY (module_id);


--
-- Name: phpbb_notification_types phpbb_notification_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_notification_types
    ADD CONSTRAINT phpbb_notification_types_pkey PRIMARY KEY (notification_type_id);


--
-- Name: phpbb_notifications phpbb_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_notifications
    ADD CONSTRAINT phpbb_notifications_pkey PRIMARY KEY (notification_id);


--
-- Name: phpbb_oauth_accounts phpbb_oauth_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_oauth_accounts
    ADD CONSTRAINT phpbb_oauth_accounts_pkey PRIMARY KEY (user_id, provider);


--
-- Name: phpbb_posts phpbb_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_posts
    ADD CONSTRAINT phpbb_posts_pkey PRIMARY KEY (post_id);


--
-- Name: phpbb_privmsgs_folder phpbb_privmsgs_folder_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_privmsgs_folder
    ADD CONSTRAINT phpbb_privmsgs_folder_pkey PRIMARY KEY (folder_id);


--
-- Name: phpbb_privmsgs phpbb_privmsgs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_privmsgs
    ADD CONSTRAINT phpbb_privmsgs_pkey PRIMARY KEY (msg_id);


--
-- Name: phpbb_privmsgs_rules phpbb_privmsgs_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_privmsgs_rules
    ADD CONSTRAINT phpbb_privmsgs_rules_pkey PRIMARY KEY (rule_id);


--
-- Name: phpbb_profile_fields_data phpbb_profile_fields_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_profile_fields_data
    ADD CONSTRAINT phpbb_profile_fields_data_pkey PRIMARY KEY (user_id);


--
-- Name: phpbb_profile_fields_lang phpbb_profile_fields_lang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_profile_fields_lang
    ADD CONSTRAINT phpbb_profile_fields_lang_pkey PRIMARY KEY (field_id, lang_id, option_id);


--
-- Name: phpbb_profile_fields phpbb_profile_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_profile_fields
    ADD CONSTRAINT phpbb_profile_fields_pkey PRIMARY KEY (field_id);


--
-- Name: phpbb_profile_lang phpbb_profile_lang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_profile_lang
    ADD CONSTRAINT phpbb_profile_lang_pkey PRIMARY KEY (field_id, lang_id);


--
-- Name: phpbb_ranks phpbb_ranks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_ranks
    ADD CONSTRAINT phpbb_ranks_pkey PRIMARY KEY (rank_id);


--
-- Name: phpbb_reports phpbb_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_reports
    ADD CONSTRAINT phpbb_reports_pkey PRIMARY KEY (report_id);


--
-- Name: phpbb_reports_reasons phpbb_reports_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_reports_reasons
    ADD CONSTRAINT phpbb_reports_reasons_pkey PRIMARY KEY (reason_id);


--
-- Name: phpbb_search_results phpbb_search_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_search_results
    ADD CONSTRAINT phpbb_search_results_pkey PRIMARY KEY (search_key);


--
-- Name: phpbb_search_wordlist phpbb_search_wordlist_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_search_wordlist
    ADD CONSTRAINT phpbb_search_wordlist_pkey PRIMARY KEY (word_id);


--
-- Name: phpbb_sessions_keys phpbb_sessions_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_sessions_keys
    ADD CONSTRAINT phpbb_sessions_keys_pkey PRIMARY KEY (key_id, user_id);


--
-- Name: phpbb_sessions phpbb_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_sessions
    ADD CONSTRAINT phpbb_sessions_pkey PRIMARY KEY (session_id);


--
-- Name: phpbb_sitelist phpbb_sitelist_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_sitelist
    ADD CONSTRAINT phpbb_sitelist_pkey PRIMARY KEY (site_id);


--
-- Name: phpbb_smilies phpbb_smilies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_smilies
    ADD CONSTRAINT phpbb_smilies_pkey PRIMARY KEY (smiley_id);


--
-- Name: phpbb_styles phpbb_styles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_styles
    ADD CONSTRAINT phpbb_styles_pkey PRIMARY KEY (style_id);


--
-- Name: phpbb_teampage phpbb_teampage_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_teampage
    ADD CONSTRAINT phpbb_teampage_pkey PRIMARY KEY (teampage_id);


--
-- Name: phpbb_topics phpbb_topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_topics
    ADD CONSTRAINT phpbb_topics_pkey PRIMARY KEY (topic_id);


--
-- Name: phpbb_topics_posted phpbb_topics_posted_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_topics_posted
    ADD CONSTRAINT phpbb_topics_posted_pkey PRIMARY KEY (user_id, topic_id);


--
-- Name: phpbb_topics_track phpbb_topics_track_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_topics_track
    ADD CONSTRAINT phpbb_topics_track_pkey PRIMARY KEY (user_id, topic_id);


--
-- Name: phpbb_users phpbb_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_users
    ADD CONSTRAINT phpbb_users_pkey PRIMARY KEY (user_id);


--
-- Name: phpbb_warnings phpbb_warnings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_warnings
    ADD CONSTRAINT phpbb_warnings_pkey PRIMARY KEY (warning_id);


--
-- Name: phpbb_words phpbb_words_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_words
    ADD CONSTRAINT phpbb_words_pkey PRIMARY KEY (word_id);


--
-- Name: phpbb_zebra phpbb_zebra_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phpbb_zebra
    ADD CONSTRAINT phpbb_zebra_pkey PRIMARY KEY (user_id, zebra_id);


--
-- Name: phpbb_acl_groups_auth_opt_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_acl_groups_auth_opt_id ON public.phpbb_acl_groups USING btree (auth_option_id);


--
-- Name: phpbb_acl_groups_auth_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_acl_groups_auth_role_id ON public.phpbb_acl_groups USING btree (auth_role_id);


--
-- Name: phpbb_acl_groups_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_acl_groups_group_id ON public.phpbb_acl_groups USING btree (group_id);


--
-- Name: phpbb_acl_options_auth_option; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX phpbb_acl_options_auth_option ON public.phpbb_acl_options USING btree (auth_option);


--
-- Name: phpbb_acl_roles_data_ath_op_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_acl_roles_data_ath_op_id ON public.phpbb_acl_roles_data USING btree (auth_option_id);


--
-- Name: phpbb_acl_roles_role_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_acl_roles_role_order ON public.phpbb_acl_roles USING btree (role_order);


--
-- Name: phpbb_acl_roles_role_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_acl_roles_role_type ON public.phpbb_acl_roles USING btree (role_type);


--
-- Name: phpbb_acl_users_auth_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_acl_users_auth_option_id ON public.phpbb_acl_users USING btree (auth_option_id);


--
-- Name: phpbb_acl_users_auth_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_acl_users_auth_role_id ON public.phpbb_acl_users USING btree (auth_role_id);


--
-- Name: phpbb_acl_users_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_acl_users_user_id ON public.phpbb_acl_users USING btree (user_id);


--
-- Name: phpbb_attachments_filetime; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_attachments_filetime ON public.phpbb_attachments USING btree (filetime);


--
-- Name: phpbb_attachments_is_orphan; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_attachments_is_orphan ON public.phpbb_attachments USING btree (is_orphan);


--
-- Name: phpbb_attachments_post_msg_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_attachments_post_msg_id ON public.phpbb_attachments USING btree (post_msg_id);


--
-- Name: phpbb_attachments_poster_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_attachments_poster_id ON public.phpbb_attachments USING btree (poster_id);


--
-- Name: phpbb_attachments_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_attachments_topic_id ON public.phpbb_attachments USING btree (topic_id);


--
-- Name: phpbb_banlist_ban_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_banlist_ban_email ON public.phpbb_banlist USING btree (ban_email, ban_exclude);


--
-- Name: phpbb_banlist_ban_end; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_banlist_ban_end ON public.phpbb_banlist USING btree (ban_end);


--
-- Name: phpbb_banlist_ban_ip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_banlist_ban_ip ON public.phpbb_banlist USING btree (ban_ip, ban_exclude);


--
-- Name: phpbb_banlist_ban_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_banlist_ban_user ON public.phpbb_banlist USING btree (ban_userid, ban_exclude);


--
-- Name: phpbb_bbcodes_display_on_post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_bbcodes_display_on_post ON public.phpbb_bbcodes USING btree (display_on_posting);


--
-- Name: phpbb_bots_bot_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_bots_bot_active ON public.phpbb_bots USING btree (bot_active);


--
-- Name: phpbb_config_is_dynamic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_config_is_dynamic ON public.phpbb_config USING btree (is_dynamic);


--
-- Name: phpbb_confirm_confirm_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_confirm_confirm_type ON public.phpbb_confirm USING btree (confirm_type);


--
-- Name: phpbb_drafts_save_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_drafts_save_time ON public.phpbb_drafts USING btree (save_time);


--
-- Name: phpbb_ext_ext_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX phpbb_ext_ext_name ON public.phpbb_ext USING btree (ext_name);


--
-- Name: phpbb_forums_forum_lastpost_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_forums_forum_lastpost_id ON public.phpbb_forums USING btree (forum_last_post_id);


--
-- Name: phpbb_forums_left_right_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_forums_left_right_id ON public.phpbb_forums USING btree (left_id, right_id);


--
-- Name: phpbb_forums_watch_forum_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_forums_watch_forum_id ON public.phpbb_forums_watch USING btree (forum_id);


--
-- Name: phpbb_forums_watch_notify_stat; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_forums_watch_notify_stat ON public.phpbb_forums_watch USING btree (notify_status);


--
-- Name: phpbb_forums_watch_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_forums_watch_user_id ON public.phpbb_forums_watch USING btree (user_id);


--
-- Name: phpbb_groups_group_legend_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_groups_group_legend_name ON public.phpbb_groups USING btree (group_legend, group_name);


--
-- Name: phpbb_icons_display_on_posting; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_icons_display_on_posting ON public.phpbb_icons USING btree (display_on_posting);


--
-- Name: phpbb_lang_lang_iso; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_lang_lang_iso ON public.phpbb_lang USING btree (lang_iso);


--
-- Name: phpbb_log_forum_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_log_forum_id ON public.phpbb_log USING btree (forum_id);


--
-- Name: phpbb_log_log_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_log_log_time ON public.phpbb_log USING btree (log_time);


--
-- Name: phpbb_log_log_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_log_log_type ON public.phpbb_log USING btree (log_type);


--
-- Name: phpbb_log_reportee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_log_reportee_id ON public.phpbb_log USING btree (reportee_id);


--
-- Name: phpbb_log_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_log_topic_id ON public.phpbb_log USING btree (topic_id);


--
-- Name: phpbb_log_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_log_user_id ON public.phpbb_log USING btree (user_id);


--
-- Name: phpbb_login_attempts_att_for; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_login_attempts_att_for ON public.phpbb_login_attempts USING btree (attempt_forwarded_for, attempt_time);


--
-- Name: phpbb_login_attempts_att_ip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_login_attempts_att_ip ON public.phpbb_login_attempts USING btree (attempt_ip, attempt_time);


--
-- Name: phpbb_login_attempts_att_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_login_attempts_att_time ON public.phpbb_login_attempts USING btree (attempt_time);


--
-- Name: phpbb_login_attempts_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_login_attempts_user_id ON public.phpbb_login_attempts USING btree (user_id);


--
-- Name: phpbb_moderator_cache_disp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_moderator_cache_disp_idx ON public.phpbb_moderator_cache USING btree (display_on_index);


--
-- Name: phpbb_moderator_cache_forum_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_moderator_cache_forum_id ON public.phpbb_moderator_cache USING btree (forum_id);


--
-- Name: phpbb_modules_class_left_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_modules_class_left_id ON public.phpbb_modules USING btree (module_class, left_id);


--
-- Name: phpbb_modules_left_right_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_modules_left_right_id ON public.phpbb_modules USING btree (left_id, right_id);


--
-- Name: phpbb_modules_module_enabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_modules_module_enabled ON public.phpbb_modules USING btree (module_enabled);


--
-- Name: phpbb_notification_types_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX phpbb_notification_types_type ON public.phpbb_notification_types USING btree (notification_type_name);


--
-- Name: phpbb_notifications_item_ident; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_notifications_item_ident ON public.phpbb_notifications USING btree (notification_type_id, item_id);


--
-- Name: phpbb_notifications_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_notifications_user ON public.phpbb_notifications USING btree (user_id, notification_read);


--
-- Name: phpbb_oauth_states_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_oauth_states_provider ON public.phpbb_oauth_states USING btree (provider);


--
-- Name: phpbb_oauth_states_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_oauth_states_user_id ON public.phpbb_oauth_states USING btree (user_id);


--
-- Name: phpbb_oauth_tokens_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_oauth_tokens_provider ON public.phpbb_oauth_tokens USING btree (provider);


--
-- Name: phpbb_oauth_tokens_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_oauth_tokens_user_id ON public.phpbb_oauth_tokens USING btree (user_id);


--
-- Name: phpbb_poll_options_poll_opt_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_poll_options_poll_opt_id ON public.phpbb_poll_options USING btree (poll_option_id);


--
-- Name: phpbb_poll_options_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_poll_options_topic_id ON public.phpbb_poll_options USING btree (topic_id);


--
-- Name: phpbb_poll_votes_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_poll_votes_topic_id ON public.phpbb_poll_votes USING btree (topic_id);


--
-- Name: phpbb_poll_votes_vote_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_poll_votes_vote_user_id ON public.phpbb_poll_votes USING btree (vote_user_id);


--
-- Name: phpbb_poll_votes_vote_user_ip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_poll_votes_vote_user_ip ON public.phpbb_poll_votes USING btree (vote_user_ip);


--
-- Name: phpbb_posts_forum_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_posts_forum_id ON public.phpbb_posts USING btree (forum_id);


--
-- Name: phpbb_posts_post_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_posts_post_username ON public.phpbb_posts USING btree (post_username);


--
-- Name: phpbb_posts_post_visibility; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_posts_post_visibility ON public.phpbb_posts USING btree (post_visibility);


--
-- Name: phpbb_posts_poster_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_posts_poster_id ON public.phpbb_posts USING btree (poster_id);


--
-- Name: phpbb_posts_poster_ip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_posts_poster_ip ON public.phpbb_posts USING btree (poster_ip);


--
-- Name: phpbb_posts_tid_post_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_posts_tid_post_time ON public.phpbb_posts USING btree (topic_id, post_time);


--
-- Name: phpbb_posts_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_posts_topic_id ON public.phpbb_posts USING btree (topic_id);


--
-- Name: phpbb_privmsgs_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_privmsgs_author_id ON public.phpbb_privmsgs USING btree (author_id);


--
-- Name: phpbb_privmsgs_author_ip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_privmsgs_author_ip ON public.phpbb_privmsgs USING btree (author_ip);


--
-- Name: phpbb_privmsgs_folder_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_privmsgs_folder_user_id ON public.phpbb_privmsgs_folder USING btree (user_id);


--
-- Name: phpbb_privmsgs_message_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_privmsgs_message_time ON public.phpbb_privmsgs USING btree (message_time);


--
-- Name: phpbb_privmsgs_root_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_privmsgs_root_level ON public.phpbb_privmsgs USING btree (root_level);


--
-- Name: phpbb_privmsgs_rules_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_privmsgs_rules_user_id ON public.phpbb_privmsgs_rules USING btree (user_id);


--
-- Name: phpbb_privmsgs_to_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_privmsgs_to_author_id ON public.phpbb_privmsgs_to USING btree (author_id);


--
-- Name: phpbb_privmsgs_to_msg_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_privmsgs_to_msg_id ON public.phpbb_privmsgs_to USING btree (msg_id);


--
-- Name: phpbb_privmsgs_to_usr_flder_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_privmsgs_to_usr_flder_id ON public.phpbb_privmsgs_to USING btree (user_id, folder_id);


--
-- Name: phpbb_profile_fields_fld_ordr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_profile_fields_fld_ordr ON public.phpbb_profile_fields USING btree (field_order);


--
-- Name: phpbb_profile_fields_fld_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_profile_fields_fld_type ON public.phpbb_profile_fields USING btree (field_type);


--
-- Name: phpbb_reports_pm_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_reports_pm_id ON public.phpbb_reports USING btree (pm_id);


--
-- Name: phpbb_reports_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_reports_post_id ON public.phpbb_reports USING btree (post_id);


--
-- Name: phpbb_search_wordlist_wrd_cnt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_search_wordlist_wrd_cnt ON public.phpbb_search_wordlist USING btree (word_count);


--
-- Name: phpbb_search_wordlist_wrd_txt; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX phpbb_search_wordlist_wrd_txt ON public.phpbb_search_wordlist USING btree (word_text);


--
-- Name: phpbb_search_wordmatch_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_search_wordmatch_post_id ON public.phpbb_search_wordmatch USING btree (post_id);


--
-- Name: phpbb_search_wordmatch_un_mtch; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX phpbb_search_wordmatch_un_mtch ON public.phpbb_search_wordmatch USING btree (word_id, post_id, title_match);


--
-- Name: phpbb_search_wordmatch_word_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_search_wordmatch_word_id ON public.phpbb_search_wordmatch USING btree (word_id);


--
-- Name: phpbb_sessions_keys_last_login; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_sessions_keys_last_login ON public.phpbb_sessions_keys USING btree (last_login);


--
-- Name: phpbb_sessions_session_fid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_sessions_session_fid ON public.phpbb_sessions USING btree (session_forum_id);


--
-- Name: phpbb_sessions_session_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_sessions_session_time ON public.phpbb_sessions USING btree (session_time);


--
-- Name: phpbb_sessions_session_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_sessions_session_user_id ON public.phpbb_sessions USING btree (session_user_id);


--
-- Name: phpbb_smilies_display_on_post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_smilies_display_on_post ON public.phpbb_smilies USING btree (display_on_posting);


--
-- Name: phpbb_styles_style_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX phpbb_styles_style_name ON public.phpbb_styles USING btree (style_name);


--
-- Name: phpbb_topics_fid_time_moved; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_topics_fid_time_moved ON public.phpbb_topics USING btree (forum_id, topic_last_post_time, topic_moved_id);


--
-- Name: phpbb_topics_forum_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_topics_forum_id ON public.phpbb_topics USING btree (forum_id);


--
-- Name: phpbb_topics_forum_id_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_topics_forum_id_type ON public.phpbb_topics USING btree (forum_id, topic_type);


--
-- Name: phpbb_topics_forum_vis_last; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_topics_forum_vis_last ON public.phpbb_topics USING btree (forum_id, topic_visibility, topic_last_post_id);


--
-- Name: phpbb_topics_last_post_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_topics_last_post_time ON public.phpbb_topics USING btree (topic_last_post_time);


--
-- Name: phpbb_topics_latest_topics; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_topics_latest_topics ON public.phpbb_topics USING btree (forum_id, topic_last_post_time, topic_last_post_id, topic_moved_id);


--
-- Name: phpbb_topics_topic_visibility; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_topics_topic_visibility ON public.phpbb_topics USING btree (topic_visibility);


--
-- Name: phpbb_topics_track_forum_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_topics_track_forum_id ON public.phpbb_topics_track USING btree (forum_id);


--
-- Name: phpbb_topics_track_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_topics_track_topic_id ON public.phpbb_topics_track USING btree (topic_id);


--
-- Name: phpbb_topics_watch_notify_stat; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_topics_watch_notify_stat ON public.phpbb_topics_watch USING btree (notify_status);


--
-- Name: phpbb_topics_watch_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_topics_watch_topic_id ON public.phpbb_topics_watch USING btree (topic_id);


--
-- Name: phpbb_topics_watch_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_topics_watch_user_id ON public.phpbb_topics_watch USING btree (user_id);


--
-- Name: phpbb_user_group_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_user_group_group_id ON public.phpbb_user_group USING btree (group_id);


--
-- Name: phpbb_user_group_group_leader; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_user_group_group_leader ON public.phpbb_user_group USING btree (group_leader);


--
-- Name: phpbb_user_group_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_user_group_user_id ON public.phpbb_user_group USING btree (user_id);


--
-- Name: phpbb_user_notifications_itm_usr_mthd; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX phpbb_user_notifications_itm_usr_mthd ON public.phpbb_user_notifications USING btree (item_type, item_id, user_id, method);


--
-- Name: phpbb_user_notifications_uid_itm_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_user_notifications_uid_itm_id ON public.phpbb_user_notifications USING btree (user_id, item_id);


--
-- Name: phpbb_user_notifications_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_user_notifications_user_id ON public.phpbb_user_notifications USING btree (user_id);


--
-- Name: phpbb_user_notifications_usr_itm_tpe; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_user_notifications_usr_itm_tpe ON public.phpbb_user_notifications USING btree (user_id, item_type, item_id);


--
-- Name: phpbb_users_user_birthday; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_users_user_birthday ON public.phpbb_users USING btree (user_birthday);


--
-- Name: phpbb_users_user_email_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_users_user_email_hash ON public.phpbb_users USING btree (user_email_hash);


--
-- Name: phpbb_users_user_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phpbb_users_user_type ON public.phpbb_users USING btree (user_type);


--
-- Name: phpbb_users_username_clean; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX phpbb_users_username_clean ON public.phpbb_users USING btree (username_clean);


--
-- PostgreSQL database dump complete
--

\unrestrict jUFXBXkU9OKeNgjjaU6XnUYZkk7P4W1XOv5NMSiwK1Pm27Idb9ameSsOEhPXnbj

