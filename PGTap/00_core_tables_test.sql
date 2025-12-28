BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(41);

-- Check extensions
SELECT has_extension('pgtap');
SELECT has_extension('pgcrypto');

-- Check tables
SELECT has_table('tenants');
SELECT has_table('account_types');
SELECT has_table('currencies');
SELECT has_table('accounts');
SELECT has_table('journal_entries');
SELECT has_table('journal_entry_lines');
SELECT has_table('account_balances');

-- Check columns for tenants
SELECT has_column('tenants', 'id');
SELECT col_type_is('tenants', 'id', 'uuid');
SELECT col_is_pk('tenants', 'id');
SELECT has_column('tenants', 'name');
SELECT col_type_is('tenants', 'name', 'character varying(255)');

-- Check columns for account_types
SELECT has_column('account_types', 'code');
SELECT col_type_is('account_types', 'code', 'character varying(50)');
SELECT col_is_unique('account_types', 'code');

-- Check columns for accounts
SELECT has_column('accounts', 'tenant_id');
SELECT col_type_is('accounts', 'tenant_id', 'uuid');
-- SELECT col_has_check('accounts');

-- Check triggers
SELECT has_trigger('tenants', 'trg_upd_tenants');
SELECT has_trigger('account_types', 'trg_upd_account_types');
SELECT has_trigger('currencies', 'trg_upd_currencies');
SELECT has_trigger('accounts', 'trg_upd_accounts');
SELECT has_trigger('journal_entries', 'trg_upd_journal_entries');
SELECT has_trigger('account_balances', 'trg_upd_account_balances');

-- Check RLS on tables
SELECT ok(rowsecurity, 'Table accounts should have RLS enabled') FROM pg_tables WHERE schemaname = 'public' AND tablename = 'accounts';
SELECT ok(rowsecurity, 'Table journal_entries should have RLS enabled') FROM pg_tables WHERE schemaname = 'public' AND tablename = 'journal_entries';
SELECT ok(rowsecurity, 'Table journal_entry_lines should have RLS enabled') FROM pg_tables WHERE schemaname = 'public' AND tablename = 'journal_entry_lines';
SELECT ok(rowsecurity, 'Table account_balances should have RLS enabled') FROM pg_tables WHERE schemaname = 'public' AND tablename = 'account_balances';

-- Check policies
SELECT policy_cmd_is('accounts', 'tenant_isolation_policy', 'ALL');
SELECT policy_cmd_is('journal_entries', 'tenant_isolation_policy', 'ALL');
SELECT policy_cmd_is('journal_entry_lines', 'tenant_isolation_policy', 'ALL');
SELECT policy_cmd_is('account_balances', 'tenant_isolation_policy', 'ALL');

-- Check functions
SELECT has_function('update_timestamp_column');

-- Verify some specific constraints
SELECT col_not_null('tenants', 'name');
SELECT col_has_default('tenants', 'id');

-- Check foreign keys
SELECT fk_ok('accounts', 'tenant_id', 'tenants', 'id');
SELECT fk_ok('accounts', 'account_type_id', 'account_types', 'id');
SELECT fk_ok('journal_entries', 'tenant_id', 'tenants', 'id');
SELECT fk_ok('journal_entry_lines', 'journal_entry_id', 'journal_entries', 'id');
SELECT fk_ok('journal_entry_lines', 'account_id', 'accounts', 'id');

SELECT * FROM finish();
ROLLBACK;
