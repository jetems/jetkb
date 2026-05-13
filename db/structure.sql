SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: jetkb_search; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.jetkb_search (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR asciiword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR word WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR hword_part WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR hword_asciipart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR asciihword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR hword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.jetkb_search
    ADD MAPPING FOR uint WITH simple;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accesses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accesses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    accessed_at timestamp(6) without time zone,
    account_id uuid NOT NULL,
    board_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    involvement character varying(255) DEFAULT 'access_only'::character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id uuid NOT NULL
);


--
-- Name: account_cancellations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_cancellations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    initiated_by_id uuid NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: account_external_id_sequences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_external_id_sequences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    value bigint DEFAULT 0 NOT NULL
);


--
-- Name: account_imports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_imports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid,
    completed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    failure_reason character varying(255),
    identity_id uuid NOT NULL,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: account_join_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_join_codes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    code character varying(255) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    usage_count bigint DEFAULT 0 NOT NULL,
    usage_limit bigint DEFAULT 10 NOT NULL
);


--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cards_count bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    external_account_id bigint,
    name character varying(255) NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: action_pack_passkeys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.action_pack_passkeys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    aaguid character varying(255),
    backed_up boolean,
    created_at timestamp(6) without time zone NOT NULL,
    credential_id character varying(255) NOT NULL,
    holder_id uuid NOT NULL,
    holder_type character varying(255) NOT NULL,
    name character varying(255),
    public_key bytea NOT NULL,
    sign_count integer DEFAULT 0 NOT NULL,
    transports text,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: action_text_rich_texts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.action_text_rich_texts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    body text,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying(255) NOT NULL,
    record_id uuid NOT NULL,
    record_type character varying(255) NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    blob_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying(255) NOT NULL,
    record_id uuid NOT NULL,
    record_type character varying(255) NOT NULL
);


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying(255),
    content_type character varying(255),
    created_at timestamp(6) without time zone NOT NULL,
    filename character varying(255) NOT NULL,
    key character varying(255) NOT NULL,
    metadata text,
    service_name character varying(255) NOT NULL
);


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    blob_id uuid NOT NULL,
    variation_digest character varying(255) NOT NULL
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying(255) NOT NULL,
    value character varying(255),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: assignees_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assignees_filters (
    assignee_id uuid NOT NULL,
    filter_id uuid NOT NULL
);


--
-- Name: assigners_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assigners_filters (
    assigner_id uuid NOT NULL,
    filter_id uuid NOT NULL
);


--
-- Name: assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    assignee_id uuid NOT NULL,
    assigner_id uuid NOT NULL,
    card_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: board_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.board_publications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    board_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    key character varying(255),
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: boards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.boards (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    all_access boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    creator_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: boards_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.boards_filters (
    board_id uuid NOT NULL,
    filter_id uuid NOT NULL
);


--
-- Name: card_activity_spikes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.card_activity_spikes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    card_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: card_goldnesses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.card_goldnesses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    card_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: card_not_nows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.card_not_nows (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    card_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id uuid
);


--
-- Name: cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cards (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    board_id uuid NOT NULL,
    column_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    creator_id uuid NOT NULL,
    due_on date,
    last_active_at timestamp(6) without time zone NOT NULL,
    number bigint NOT NULL,
    status character varying(255) DEFAULT 'drafted'::character varying NOT NULL,
    title character varying(255),
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: closers_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.closers_filters (
    closer_id uuid NOT NULL,
    filter_id uuid NOT NULL
);


--
-- Name: closures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.closures (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    card_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id uuid
);


--
-- Name: columns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.columns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    board_id uuid NOT NULL,
    color character varying(255) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying(255) NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    card_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    creator_id uuid NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: creators_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.creators_filters (
    creator_id uuid NOT NULL,
    filter_id uuid NOT NULL
);


--
-- Name: entropies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entropies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    auto_postpone_period bigint DEFAULT 2592000 NOT NULL,
    container_id uuid NOT NULL,
    container_type character varying(255) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    action character varying(255) NOT NULL,
    board_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    creator_id uuid NOT NULL,
    eventable_id uuid NOT NULL,
    eventable_type character varying(255) NOT NULL,
    particulars jsonb DEFAULT '{}'::jsonb,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: exports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    completed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    type character varying(255),
    updated_at timestamp(6) without time zone NOT NULL,
    user_id uuid NOT NULL
);


--
-- Name: filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.filters (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    creator_id uuid NOT NULL,
    fields jsonb DEFAULT '{}'::jsonb NOT NULL,
    params_digest character varying(255) NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: filters_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.filters_tags (
    filter_id uuid NOT NULL,
    tag_id uuid NOT NULL
);


--
-- Name: identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    email_address character varying(255) NOT NULL,
    staff boolean DEFAULT false NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: identity_access_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identity_access_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    description text,
    identity_id uuid NOT NULL,
    permission character varying(255),
    token character varying(255),
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: magic_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.magic_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(255) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    identity_id uuid,
    purpose integer NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: mentions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mentions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    mentionee_id uuid NOT NULL,
    mentioner_id uuid NOT NULL,
    source_id uuid NOT NULL,
    source_type character varying(255) NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: notification_bundles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_bundles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    ends_at timestamp(6) without time zone NOT NULL,
    starts_at timestamp(6) without time zone NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id uuid NOT NULL
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    card_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    creator_id uuid,
    read_at timestamp(6) without time zone,
    source_id uuid NOT NULL,
    source_type character varying(255) NOT NULL,
    unread_count integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id uuid NOT NULL
);


--
-- Name: pins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    card_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id uuid NOT NULL
);


--
-- Name: push_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    auth_key character varying(255),
    created_at timestamp(6) without time zone NOT NULL,
    endpoint text,
    p256dh_key character varying(255),
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying(4096),
    user_id uuid NOT NULL
);


--
-- Name: reactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    content character varying(16) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    reactable_id uuid NOT NULL,
    reactable_type character varying(255) NOT NULL,
    reacter_id uuid NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: search_queries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_queries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    terms character varying(2000) NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id uuid NOT NULL
);


--
-- Name: search_records_0; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_0 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_1; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_1 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_10 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_11 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_12 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_13; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_13 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_14; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_14 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_15; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_15 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_2; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_2 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_3; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_3 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_4; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_4 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_5; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_5 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_6; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_6 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_7; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_7 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_8; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_8 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: search_records_9; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_records_9 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    account_key character varying(255) DEFAULT ''::character varying NOT NULL,
    board_id uuid NOT NULL,
    card_id uuid NOT NULL,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    searchable_id uuid NOT NULL,
    searchable_type character varying(255) NOT NULL,
    title character varying(255),
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('public.jetkb_search'::regconfig, (((((COALESCE(account_key, ''::character varying))::text || ' '::text) || (COALESCE(title, ''::character varying))::text) || ' '::text) || COALESCE(content, ''::text)))) STORED
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    identity_id uuid NOT NULL,
    ip_address character varying(255),
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying(4096)
);


--
-- Name: steps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.steps (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    card_id uuid NOT NULL,
    completed boolean DEFAULT false NOT NULL,
    content text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: storage_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.storage_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    blob_id uuid,
    board_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    delta bigint NOT NULL,
    operation character varying(255) NOT NULL,
    recordable_id uuid,
    recordable_type character varying(255),
    request_id character varying(255),
    user_id uuid
);


--
-- Name: storage_totals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.storage_totals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bytes_stored bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    last_entry_id uuid,
    owner_id uuid NOT NULL,
    owner_type character varying(255) NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: taggings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taggings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    card_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    tag_id uuid NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    title character varying(255),
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    bundle_email_frequency integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    timezone_name character varying(255),
    updated_at timestamp(6) without time zone NOT NULL,
    user_id uuid NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    identity_id uuid,
    name character varying(255) NOT NULL,
    role character varying(255) DEFAULT 'member'::character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    verified_at timestamp(6) without time zone
);


--
-- Name: watches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.watches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    card_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id uuid NOT NULL,
    watching boolean DEFAULT true NOT NULL
);


--
-- Name: webhook_delinquency_trackers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_delinquency_trackers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    consecutive_failures_count integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    first_failure_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone NOT NULL,
    webhook_id uuid NOT NULL
);


--
-- Name: webhook_deliveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_deliveries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    event_id uuid NOT NULL,
    request text,
    response text,
    state character varying(255) NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    webhook_id uuid NOT NULL
);


--
-- Name: webhooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhooks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    active boolean DEFAULT true NOT NULL,
    board_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying(255),
    signing_secret character varying(255) NOT NULL,
    subscribed_actions text,
    updated_at timestamp(6) without time zone NOT NULL,
    url text NOT NULL
);


--
-- Name: accesses accesses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accesses
    ADD CONSTRAINT accesses_pkey PRIMARY KEY (id);


--
-- Name: account_cancellations account_cancellations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_cancellations
    ADD CONSTRAINT account_cancellations_pkey PRIMARY KEY (id);


--
-- Name: account_external_id_sequences account_external_id_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_external_id_sequences
    ADD CONSTRAINT account_external_id_sequences_pkey PRIMARY KEY (id);


--
-- Name: account_imports account_imports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_imports
    ADD CONSTRAINT account_imports_pkey PRIMARY KEY (id);


--
-- Name: account_join_codes account_join_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_join_codes
    ADD CONSTRAINT account_join_codes_pkey PRIMARY KEY (id);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: action_pack_passkeys action_pack_passkeys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_pack_passkeys
    ADD CONSTRAINT action_pack_passkeys_pkey PRIMARY KEY (id);


--
-- Name: action_text_rich_texts action_text_rich_texts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_text_rich_texts
    ADD CONSTRAINT action_text_rich_texts_pkey PRIMARY KEY (id);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: assignments assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT assignments_pkey PRIMARY KEY (id);


--
-- Name: board_publications board_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.board_publications
    ADD CONSTRAINT board_publications_pkey PRIMARY KEY (id);


--
-- Name: boards boards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boards
    ADD CONSTRAINT boards_pkey PRIMARY KEY (id);


--
-- Name: card_activity_spikes card_activity_spikes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_activity_spikes
    ADD CONSTRAINT card_activity_spikes_pkey PRIMARY KEY (id);


--
-- Name: card_goldnesses card_goldnesses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_goldnesses
    ADD CONSTRAINT card_goldnesses_pkey PRIMARY KEY (id);


--
-- Name: card_not_nows card_not_nows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_not_nows
    ADD CONSTRAINT card_not_nows_pkey PRIMARY KEY (id);


--
-- Name: cards cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (id);


--
-- Name: closures closures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.closures
    ADD CONSTRAINT closures_pkey PRIMARY KEY (id);


--
-- Name: columns columns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.columns
    ADD CONSTRAINT columns_pkey PRIMARY KEY (id);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: entropies entropies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entropies
    ADD CONSTRAINT entropies_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: exports exports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exports
    ADD CONSTRAINT exports_pkey PRIMARY KEY (id);


--
-- Name: filters filters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.filters
    ADD CONSTRAINT filters_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: identity_access_tokens identity_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_access_tokens
    ADD CONSTRAINT identity_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: magic_links magic_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.magic_links
    ADD CONSTRAINT magic_links_pkey PRIMARY KEY (id);


--
-- Name: mentions mentions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mentions
    ADD CONSTRAINT mentions_pkey PRIMARY KEY (id);


--
-- Name: notification_bundles notification_bundles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_bundles
    ADD CONSTRAINT notification_bundles_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: pins pins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pins
    ADD CONSTRAINT pins_pkey PRIMARY KEY (id);


--
-- Name: push_subscriptions push_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: reactions reactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reactions
    ADD CONSTRAINT reactions_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: search_queries search_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_queries
    ADD CONSTRAINT search_queries_pkey PRIMARY KEY (id);


--
-- Name: search_records_0 search_records_0_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_0
    ADD CONSTRAINT search_records_0_pkey PRIMARY KEY (id);


--
-- Name: search_records_10 search_records_10_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_10
    ADD CONSTRAINT search_records_10_pkey PRIMARY KEY (id);


--
-- Name: search_records_11 search_records_11_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_11
    ADD CONSTRAINT search_records_11_pkey PRIMARY KEY (id);


--
-- Name: search_records_12 search_records_12_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_12
    ADD CONSTRAINT search_records_12_pkey PRIMARY KEY (id);


--
-- Name: search_records_13 search_records_13_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_13
    ADD CONSTRAINT search_records_13_pkey PRIMARY KEY (id);


--
-- Name: search_records_14 search_records_14_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_14
    ADD CONSTRAINT search_records_14_pkey PRIMARY KEY (id);


--
-- Name: search_records_15 search_records_15_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_15
    ADD CONSTRAINT search_records_15_pkey PRIMARY KEY (id);


--
-- Name: search_records_1 search_records_1_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_1
    ADD CONSTRAINT search_records_1_pkey PRIMARY KEY (id);


--
-- Name: search_records_2 search_records_2_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_2
    ADD CONSTRAINT search_records_2_pkey PRIMARY KEY (id);


--
-- Name: search_records_3 search_records_3_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_3
    ADD CONSTRAINT search_records_3_pkey PRIMARY KEY (id);


--
-- Name: search_records_4 search_records_4_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_4
    ADD CONSTRAINT search_records_4_pkey PRIMARY KEY (id);


--
-- Name: search_records_5 search_records_5_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_5
    ADD CONSTRAINT search_records_5_pkey PRIMARY KEY (id);


--
-- Name: search_records_6 search_records_6_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_6
    ADD CONSTRAINT search_records_6_pkey PRIMARY KEY (id);


--
-- Name: search_records_7 search_records_7_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_7
    ADD CONSTRAINT search_records_7_pkey PRIMARY KEY (id);


--
-- Name: search_records_8 search_records_8_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_8
    ADD CONSTRAINT search_records_8_pkey PRIMARY KEY (id);


--
-- Name: search_records_9 search_records_9_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_records_9
    ADD CONSTRAINT search_records_9_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: steps steps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.steps
    ADD CONSTRAINT steps_pkey PRIMARY KEY (id);


--
-- Name: storage_entries storage_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_entries
    ADD CONSTRAINT storage_entries_pkey PRIMARY KEY (id);


--
-- Name: storage_totals storage_totals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_totals
    ADD CONSTRAINT storage_totals_pkey PRIMARY KEY (id);


--
-- Name: taggings taggings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taggings
    ADD CONSTRAINT taggings_pkey PRIMARY KEY (id);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: user_settings user_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_settings
    ADD CONSTRAINT user_settings_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: watches watches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watches
    ADD CONSTRAINT watches_pkey PRIMARY KEY (id);


--
-- Name: webhook_delinquency_trackers webhook_delinquency_trackers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_delinquency_trackers
    ADD CONSTRAINT webhook_delinquency_trackers_pkey PRIMARY KEY (id);


--
-- Name: webhook_deliveries webhook_deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_deliveries
    ADD CONSTRAINT webhook_deliveries_pkey PRIMARY KEY (id);


--
-- Name: webhooks webhooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhooks
    ADD CONSTRAINT webhooks_pkey PRIMARY KEY (id);


--
-- Name: idx_on_container_type_container_id_auto_postpone_pe_3d79b50517; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_container_type_container_id_auto_postpone_pe_3d79b50517 ON public.entropies USING btree (container_type, container_id, auto_postpone_period);


--
-- Name: idx_on_user_id_starts_at_ends_at_7eae5d3ac5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_user_id_starts_at_ends_at_7eae5d3ac5 ON public.notification_bundles USING btree (user_id, starts_at, ends_at);


--
-- Name: index_access_token_on_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_access_token_on_identity_id ON public.identity_access_tokens USING btree (identity_id);


--
-- Name: index_accesses_on_account_id_and_accessed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accesses_on_account_id_and_accessed_at ON public.accesses USING btree (account_id, accessed_at);


--
-- Name: index_accesses_on_board_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accesses_on_board_id ON public.accesses USING btree (board_id);


--
-- Name: index_accesses_on_board_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_accesses_on_board_id_and_user_id ON public.accesses USING btree (board_id, user_id);


--
-- Name: index_accesses_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accesses_on_user_id ON public.accesses USING btree (user_id);


--
-- Name: index_account_cancellations_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_account_cancellations_on_account_id ON public.account_cancellations USING btree (account_id);


--
-- Name: index_account_external_id_sequences_on_value; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_account_external_id_sequences_on_value ON public.account_external_id_sequences USING btree (value);


--
-- Name: index_account_imports_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_imports_on_account_id ON public.account_imports USING btree (account_id);


--
-- Name: index_account_imports_on_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_imports_on_identity_id ON public.account_imports USING btree (identity_id);


--
-- Name: index_account_join_codes_on_account_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_account_join_codes_on_account_id_and_code ON public.account_join_codes USING btree (account_id, code);


--
-- Name: index_accounts_on_external_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_accounts_on_external_account_id ON public.accounts USING btree (external_account_id);


--
-- Name: index_action_pack_passkeys_on_credential_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_action_pack_passkeys_on_credential_id ON public.action_pack_passkeys USING btree (credential_id);


--
-- Name: index_action_pack_passkeys_on_holder_type_and_holder_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_action_pack_passkeys_on_holder_type_and_holder_id ON public.action_pack_passkeys USING btree (holder_type, holder_id);


--
-- Name: index_action_text_rich_texts_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_action_text_rich_texts_on_account_id ON public.action_text_rich_texts USING btree (account_id);


--
-- Name: index_action_text_rich_texts_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_action_text_rich_texts_uniqueness ON public.action_text_rich_texts USING btree (record_type, record_id, name);


--
-- Name: index_active_storage_attachments_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_account_id ON public.active_storage_attachments USING btree (account_id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_blobs_on_account_id ON public.active_storage_blobs USING btree (account_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_variant_records_on_account_id ON public.active_storage_variant_records USING btree (account_id);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_assignees_filters_on_assignee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assignees_filters_on_assignee_id ON public.assignees_filters USING btree (assignee_id);


--
-- Name: index_assignees_filters_on_filter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assignees_filters_on_filter_id ON public.assignees_filters USING btree (filter_id);


--
-- Name: index_assigners_filters_on_assigner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assigners_filters_on_assigner_id ON public.assigners_filters USING btree (assigner_id);


--
-- Name: index_assigners_filters_on_filter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assigners_filters_on_filter_id ON public.assigners_filters USING btree (filter_id);


--
-- Name: index_assignments_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assignments_on_account_id ON public.assignments USING btree (account_id);


--
-- Name: index_assignments_on_assignee_id_and_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_assignments_on_assignee_id_and_card_id ON public.assignments USING btree (assignee_id, card_id);


--
-- Name: index_assignments_on_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assignments_on_card_id ON public.assignments USING btree (card_id);


--
-- Name: index_board_publications_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_board_publications_on_account_id ON public.board_publications USING btree (account_id);


--
-- Name: index_board_publications_on_board_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_board_publications_on_board_id ON public.board_publications USING btree (board_id);


--
-- Name: index_board_publications_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_board_publications_on_key ON public.board_publications USING btree (key);


--
-- Name: index_boards_filters_on_board_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_boards_filters_on_board_id ON public.boards_filters USING btree (board_id);


--
-- Name: index_boards_filters_on_filter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_boards_filters_on_filter_id ON public.boards_filters USING btree (filter_id);


--
-- Name: index_boards_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_boards_on_account_id ON public.boards USING btree (account_id);


--
-- Name: index_boards_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_boards_on_creator_id ON public.boards USING btree (creator_id);


--
-- Name: index_card_activity_spikes_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_card_activity_spikes_on_account_id ON public.card_activity_spikes USING btree (account_id);


--
-- Name: index_card_activity_spikes_on_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_card_activity_spikes_on_card_id ON public.card_activity_spikes USING btree (card_id);


--
-- Name: index_card_goldnesses_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_card_goldnesses_on_account_id ON public.card_goldnesses USING btree (account_id);


--
-- Name: index_card_goldnesses_on_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_card_goldnesses_on_card_id ON public.card_goldnesses USING btree (card_id);


--
-- Name: index_card_not_nows_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_card_not_nows_on_account_id ON public.card_not_nows USING btree (account_id);


--
-- Name: index_card_not_nows_on_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_card_not_nows_on_card_id ON public.card_not_nows USING btree (card_id);


--
-- Name: index_card_not_nows_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_card_not_nows_on_user_id ON public.card_not_nows USING btree (user_id);


--
-- Name: index_cards_on_account_id_and_last_active_at_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_account_id_and_last_active_at_and_status ON public.cards USING btree (account_id, last_active_at, status);


--
-- Name: index_cards_on_account_id_and_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cards_on_account_id_and_number ON public.cards USING btree (account_id, number);


--
-- Name: index_cards_on_board_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_board_id ON public.cards USING btree (board_id);


--
-- Name: index_cards_on_column_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_column_id ON public.cards USING btree (column_id);


--
-- Name: index_closers_filters_on_closer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_closers_filters_on_closer_id ON public.closers_filters USING btree (closer_id);


--
-- Name: index_closers_filters_on_filter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_closers_filters_on_filter_id ON public.closers_filters USING btree (filter_id);


--
-- Name: index_closures_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_closures_on_account_id ON public.closures USING btree (account_id);


--
-- Name: index_closures_on_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_closures_on_card_id ON public.closures USING btree (card_id);


--
-- Name: index_closures_on_card_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_closures_on_card_id_and_created_at ON public.closures USING btree (card_id, created_at);


--
-- Name: index_closures_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_closures_on_user_id ON public.closures USING btree (user_id);


--
-- Name: index_columns_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_columns_on_account_id ON public.columns USING btree (account_id);


--
-- Name: index_columns_on_board_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_columns_on_board_id ON public.columns USING btree (board_id);


--
-- Name: index_columns_on_board_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_columns_on_board_id_and_position ON public.columns USING btree (board_id, "position");


--
-- Name: index_comments_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_account_id ON public.comments USING btree (account_id);


--
-- Name: index_comments_on_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_card_id ON public.comments USING btree (card_id);


--
-- Name: index_creators_filters_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_creators_filters_on_creator_id ON public.creators_filters USING btree (creator_id);


--
-- Name: index_creators_filters_on_filter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_creators_filters_on_filter_id ON public.creators_filters USING btree (filter_id);


--
-- Name: index_entropies_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entropies_on_account_id ON public.entropies USING btree (account_id);


--
-- Name: index_entropy_configurations_on_container; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_entropy_configurations_on_container ON public.entropies USING btree (container_type, container_id);


--
-- Name: index_events_on_account_id_and_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_account_id_and_action ON public.events USING btree (account_id, action);


--
-- Name: index_events_on_board_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_board_id ON public.events USING btree (board_id);


--
-- Name: index_events_on_board_id_and_action_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_board_id_and_action_and_created_at ON public.events USING btree (board_id, action, created_at);


--
-- Name: index_events_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_creator_id ON public.events USING btree (creator_id);


--
-- Name: index_events_on_eventable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_eventable ON public.events USING btree (eventable_type, eventable_id);


--
-- Name: index_exports_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exports_on_account_id ON public.exports USING btree (account_id);


--
-- Name: index_exports_on_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exports_on_type ON public.exports USING btree (type);


--
-- Name: index_exports_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exports_on_user_id ON public.exports USING btree (user_id);


--
-- Name: index_filters_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_filters_on_account_id ON public.filters USING btree (account_id);


--
-- Name: index_filters_on_creator_id_and_params_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_filters_on_creator_id_and_params_digest ON public.filters USING btree (creator_id, params_digest);


--
-- Name: index_filters_tags_on_filter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_filters_tags_on_filter_id ON public.filters_tags USING btree (filter_id);


--
-- Name: index_filters_tags_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_filters_tags_on_tag_id ON public.filters_tags USING btree (tag_id);


--
-- Name: index_identities_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_identities_on_email_address ON public.identities USING btree (email_address);


--
-- Name: index_magic_links_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_magic_links_on_code ON public.magic_links USING btree (code);


--
-- Name: index_magic_links_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_magic_links_on_expires_at ON public.magic_links USING btree (expires_at);


--
-- Name: index_magic_links_on_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_magic_links_on_identity_id ON public.magic_links USING btree (identity_id);


--
-- Name: index_mentions_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mentions_on_account_id ON public.mentions USING btree (account_id);


--
-- Name: index_mentions_on_mentionee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mentions_on_mentionee_id ON public.mentions USING btree (mentionee_id);


--
-- Name: index_mentions_on_mentioner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mentions_on_mentioner_id ON public.mentions USING btree (mentioner_id);


--
-- Name: index_mentions_on_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mentions_on_source ON public.mentions USING btree (source_type, source_id);


--
-- Name: index_notification_bundles_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_bundles_on_account_id ON public.notification_bundles USING btree (account_id);


--
-- Name: index_notification_bundles_on_ends_at_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_bundles_on_ends_at_and_status ON public.notification_bundles USING btree (ends_at, status);


--
-- Name: index_notification_bundles_on_user_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_bundles_on_user_id_and_status ON public.notification_bundles USING btree (user_id, status);


--
-- Name: index_notifications_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_account_id ON public.notifications USING btree (account_id);


--
-- Name: index_notifications_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_creator_id ON public.notifications USING btree (creator_id);


--
-- Name: index_notifications_on_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_source ON public.notifications USING btree (source_type, source_id);


--
-- Name: index_notifications_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_user_id ON public.notifications USING btree (user_id);


--
-- Name: index_notifications_on_user_id_and_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_notifications_on_user_id_and_card_id ON public.notifications USING btree (user_id, card_id);


--
-- Name: index_notifications_on_user_id_and_read_at_and_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_user_id_and_read_at_and_updated_at ON public.notifications USING btree (user_id, read_at DESC, updated_at DESC);


--
-- Name: index_pins_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pins_on_account_id ON public.pins USING btree (account_id);


--
-- Name: index_pins_on_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pins_on_card_id ON public.pins USING btree (card_id);


--
-- Name: index_pins_on_card_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pins_on_card_id_and_user_id ON public.pins USING btree (card_id, user_id);


--
-- Name: index_pins_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pins_on_user_id ON public.pins USING btree (user_id);


--
-- Name: index_push_subscriptions_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_push_subscriptions_on_account_id ON public.push_subscriptions USING btree (account_id);


--
-- Name: index_push_subscriptions_on_user_id_and_endpoint; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_push_subscriptions_on_user_id_and_endpoint ON public.push_subscriptions USING btree (user_id, endpoint);


--
-- Name: index_reactions_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reactions_on_account_id ON public.reactions USING btree (account_id);


--
-- Name: index_reactions_on_reactable_type_and_reactable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reactions_on_reactable_type_and_reactable_id ON public.reactions USING btree (reactable_type, reactable_id);


--
-- Name: index_reactions_on_reacter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reactions_on_reacter_id ON public.reactions USING btree (reacter_id);


--
-- Name: index_search_queries_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_queries_on_account_id ON public.search_queries USING btree (account_id);


--
-- Name: index_search_queries_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_queries_on_user_id ON public.search_queries USING btree (user_id);


--
-- Name: index_search_queries_on_user_id_and_terms; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_queries_on_user_id_and_terms ON public.search_queries USING btree (user_id, terms);


--
-- Name: index_search_queries_on_user_id_and_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_queries_on_user_id_and_updated_at ON public.search_queries USING btree (user_id, updated_at);


--
-- Name: index_search_records_0_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_0_on_account_id ON public.search_records_0 USING btree (account_id);


--
-- Name: index_search_records_0_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_0_on_searchable_type_and_searchable_id ON public.search_records_0 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_10_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_10_on_account_id ON public.search_records_10 USING btree (account_id);


--
-- Name: index_search_records_10_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_10_on_searchable_type_and_searchable_id ON public.search_records_10 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_11_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_11_on_account_id ON public.search_records_11 USING btree (account_id);


--
-- Name: index_search_records_11_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_11_on_searchable_type_and_searchable_id ON public.search_records_11 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_12_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_12_on_account_id ON public.search_records_12 USING btree (account_id);


--
-- Name: index_search_records_12_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_12_on_searchable_type_and_searchable_id ON public.search_records_12 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_13_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_13_on_account_id ON public.search_records_13 USING btree (account_id);


--
-- Name: index_search_records_13_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_13_on_searchable_type_and_searchable_id ON public.search_records_13 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_14_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_14_on_account_id ON public.search_records_14 USING btree (account_id);


--
-- Name: index_search_records_14_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_14_on_searchable_type_and_searchable_id ON public.search_records_14 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_15_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_15_on_account_id ON public.search_records_15 USING btree (account_id);


--
-- Name: index_search_records_15_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_15_on_searchable_type_and_searchable_id ON public.search_records_15 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_1_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_1_on_account_id ON public.search_records_1 USING btree (account_id);


--
-- Name: index_search_records_1_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_1_on_searchable_type_and_searchable_id ON public.search_records_1 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_2_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_2_on_account_id ON public.search_records_2 USING btree (account_id);


--
-- Name: index_search_records_2_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_2_on_searchable_type_and_searchable_id ON public.search_records_2 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_3_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_3_on_account_id ON public.search_records_3 USING btree (account_id);


--
-- Name: index_search_records_3_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_3_on_searchable_type_and_searchable_id ON public.search_records_3 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_4_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_4_on_account_id ON public.search_records_4 USING btree (account_id);


--
-- Name: index_search_records_4_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_4_on_searchable_type_and_searchable_id ON public.search_records_4 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_5_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_5_on_account_id ON public.search_records_5 USING btree (account_id);


--
-- Name: index_search_records_5_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_5_on_searchable_type_and_searchable_id ON public.search_records_5 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_6_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_6_on_account_id ON public.search_records_6 USING btree (account_id);


--
-- Name: index_search_records_6_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_6_on_searchable_type_and_searchable_id ON public.search_records_6 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_7_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_7_on_account_id ON public.search_records_7 USING btree (account_id);


--
-- Name: index_search_records_7_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_7_on_searchable_type_and_searchable_id ON public.search_records_7 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_8_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_8_on_account_id ON public.search_records_8 USING btree (account_id);


--
-- Name: index_search_records_8_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_8_on_searchable_type_and_searchable_id ON public.search_records_8 USING btree (searchable_type, searchable_id);


--
-- Name: index_search_records_9_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_records_9_on_account_id ON public.search_records_9 USING btree (account_id);


--
-- Name: index_search_records_9_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_search_records_9_on_searchable_type_and_searchable_id ON public.search_records_9 USING btree (searchable_type, searchable_id);


--
-- Name: index_sessions_on_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_identity_id ON public.sessions USING btree (identity_id);


--
-- Name: index_steps_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_steps_on_account_id ON public.steps USING btree (account_id);


--
-- Name: index_steps_on_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_steps_on_card_id ON public.steps USING btree (card_id);


--
-- Name: index_steps_on_card_id_and_completed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_steps_on_card_id_and_completed ON public.steps USING btree (card_id, completed);


--
-- Name: index_storage_entries_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_storage_entries_on_account_id ON public.storage_entries USING btree (account_id);


--
-- Name: index_storage_entries_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_storage_entries_on_blob_id ON public.storage_entries USING btree (blob_id);


--
-- Name: index_storage_entries_on_board_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_storage_entries_on_board_id ON public.storage_entries USING btree (board_id);


--
-- Name: index_storage_entries_on_recordable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_storage_entries_on_recordable ON public.storage_entries USING btree (recordable_type, recordable_id);


--
-- Name: index_storage_entries_on_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_storage_entries_on_request_id ON public.storage_entries USING btree (request_id);


--
-- Name: index_storage_entries_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_storage_entries_on_user_id ON public.storage_entries USING btree (user_id);


--
-- Name: index_storage_totals_on_owner_type_and_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_storage_totals_on_owner_type_and_owner_id ON public.storage_totals USING btree (owner_type, owner_id);


--
-- Name: index_taggings_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taggings_on_account_id ON public.taggings USING btree (account_id);


--
-- Name: index_taggings_on_card_id_and_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_taggings_on_card_id_and_tag_id ON public.taggings USING btree (card_id, tag_id);


--
-- Name: index_taggings_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taggings_on_tag_id ON public.taggings USING btree (tag_id);


--
-- Name: index_tags_on_account_id_and_title; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tags_on_account_id_and_title ON public.tags USING btree (account_id, title);


--
-- Name: index_user_settings_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_settings_on_account_id ON public.user_settings USING btree (account_id);


--
-- Name: index_user_settings_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_settings_on_user_id ON public.user_settings USING btree (user_id);


--
-- Name: index_user_settings_on_user_id_and_bundle_email_frequency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_settings_on_user_id_and_bundle_email_frequency ON public.user_settings USING btree (user_id, bundle_email_frequency);


--
-- Name: index_users_on_account_id_and_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_account_id_and_identity_id ON public.users USING btree (account_id, identity_id);


--
-- Name: index_users_on_account_id_and_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_account_id_and_role ON public.users USING btree (account_id, role);


--
-- Name: index_users_on_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_identity_id ON public.users USING btree (identity_id);


--
-- Name: index_watches_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watches_on_account_id ON public.watches USING btree (account_id);


--
-- Name: index_watches_on_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watches_on_card_id ON public.watches USING btree (card_id);


--
-- Name: index_watches_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watches_on_user_id ON public.watches USING btree (user_id);


--
-- Name: index_watches_on_user_id_and_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watches_on_user_id_and_card_id ON public.watches USING btree (user_id, card_id);


--
-- Name: index_webhook_delinquency_trackers_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_delinquency_trackers_on_account_id ON public.webhook_delinquency_trackers USING btree (account_id);


--
-- Name: index_webhook_delinquency_trackers_on_webhook_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_delinquency_trackers_on_webhook_id ON public.webhook_delinquency_trackers USING btree (webhook_id);


--
-- Name: index_webhook_deliveries_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_deliveries_on_account_id ON public.webhook_deliveries USING btree (account_id);


--
-- Name: index_webhook_deliveries_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_deliveries_on_created_at ON public.webhook_deliveries USING btree (created_at);


--
-- Name: index_webhook_deliveries_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_deliveries_on_event_id ON public.webhook_deliveries USING btree (event_id);


--
-- Name: index_webhook_deliveries_on_webhook_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_deliveries_on_webhook_id ON public.webhook_deliveries USING btree (webhook_id);


--
-- Name: index_webhooks_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhooks_on_account_id ON public.webhooks USING btree (account_id);


--
-- Name: index_webhooks_on_board_id_and_subscribed_actions; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhooks_on_board_id_and_subscribed_actions ON public.webhooks USING btree (board_id, subscribed_actions);


--
-- Name: search_records_0_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_0_search_gin ON public.search_records_0 USING gin (search_vector);


--
-- Name: search_records_10_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_10_search_gin ON public.search_records_10 USING gin (search_vector);


--
-- Name: search_records_11_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_11_search_gin ON public.search_records_11 USING gin (search_vector);


--
-- Name: search_records_12_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_12_search_gin ON public.search_records_12 USING gin (search_vector);


--
-- Name: search_records_13_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_13_search_gin ON public.search_records_13 USING gin (search_vector);


--
-- Name: search_records_14_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_14_search_gin ON public.search_records_14 USING gin (search_vector);


--
-- Name: search_records_15_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_15_search_gin ON public.search_records_15 USING gin (search_vector);


--
-- Name: search_records_1_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_1_search_gin ON public.search_records_1 USING gin (search_vector);


--
-- Name: search_records_2_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_2_search_gin ON public.search_records_2 USING gin (search_vector);


--
-- Name: search_records_3_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_3_search_gin ON public.search_records_3 USING gin (search_vector);


--
-- Name: search_records_4_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_4_search_gin ON public.search_records_4 USING gin (search_vector);


--
-- Name: search_records_5_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_5_search_gin ON public.search_records_5 USING gin (search_vector);


--
-- Name: search_records_6_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_6_search_gin ON public.search_records_6 USING gin (search_vector);


--
-- Name: search_records_7_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_7_search_gin ON public.search_records_7 USING gin (search_vector);


--
-- Name: search_records_8_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_8_search_gin ON public.search_records_8 USING gin (search_vector);


--
-- Name: search_records_9_search_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_records_9_search_gin ON public.search_records_9 USING gin (search_vector);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('2'),
('1');

