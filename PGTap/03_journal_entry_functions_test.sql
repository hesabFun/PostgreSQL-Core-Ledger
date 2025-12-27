BEGIN;
SELECT plan(9);

-- Setup: Create a tenant, account type, currency, and accounts
INSERT INTO tenants (id, name) VALUES ('00000000-0000-0000-0000-000000000001', 'Test Tenant');
SELECT set_config('app.current_tenant_id', '00000000-0000-0000-0000-000000000001', true);
INSERT INTO account_types (id, code, name, normal_balance) VALUES (1, 'ASSET', 'Asset', 'DEBIT');
INSERT INTO account_types (id, code, name, normal_balance) VALUES (2, 'REVENUE', 'Revenue', 'CREDIT');
INSERT INTO currencies (code, name, symbol) VALUES ('USD', 'US Dollar', '$');

-- Use the create_account function (assuming it works as intended despite the inconsistency found earlier)
-- We'll manually insert for now to be sure of the state
INSERT INTO accounts (id, tenant_id, account_number, name, account_type_id, currency_code)
VALUES ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000001', '1001', 'Cash', 1, 'USD');
INSERT INTO accounts (id, tenant_id, account_number, name, account_type_id, currency_code)
VALUES ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000001', '4001', 'Sales', 2, 'USD');

INSERT INTO account_balances (account_id) VALUES ('00000000-0000-0000-0000-000000000101');
INSERT INTO account_balances (account_id) VALUES ('00000000-0000-0000-0000-000000000102');

-- Test 1: Check if function exists
SELECT has_function('create_journal_entry', ARRAY['character varying', 'text', 'timestamp with time zone', 'jsonb', 'jsonb']);

-- Test 2: Successful creation of a balanced entry
SELECT lives_ok(
    $$ SELECT create_journal_entry(
        'REF-001',
        'Initial Sale',
        CURRENT_TIMESTAMP,
        '[
            {"account_id": "00000000-0000-0000-0000-000000000101", "debit": 100.00, "credit": 0.00, "description": "Cash in"},
            {"account_id": "00000000-0000-0000-0000-000000000102", "debit": 0.00, "credit": 100.00, "description": "Sales revenue"}
        ]'::jsonb
    ) $$,
    'create_journal_entry should succeed for balanced lines'
);

-- Test 3: Verify entry exists
SELECT is(
    (SELECT count(*) FROM journal_entries WHERE reference_number = 'REF-001'),
    1::bigint,
    'Journal entry should exist'
);

-- Test 4: Verify lines exist
SELECT is(
    (SELECT count(*) FROM journal_entry_lines jel
     JOIN journal_entries je ON jel.journal_entry_id = je.id
     WHERE je.reference_number = 'REF-001'),
    2::bigint,
    'Two journal entry lines should exist'
);

-- Test 5: Verify Cash account debit balance
SELECT is(
    (SELECT debit_balance FROM account_balances WHERE account_id = '00000000-0000-0000-0000-000000000101'),
    100.0000::numeric,
    'Cash account debit balance should be 100'
);

-- Test 6: Verify Sales account credit balance
SELECT is(
    (SELECT credit_balance FROM account_balances WHERE account_id = '00000000-0000-0000-0000-000000000102'),
    100.0000::numeric,
    'Sales account credit balance should be 100'
);

-- Test 7: Unbalanced entry should fail (will do this in a separate block or use throws_ok if available)
SELECT throws_ok(
    $$ SELECT create_journal_entry(
        'REF-FAIL',
        'Unbalanced',
        CURRENT_TIMESTAMP,
        '[
            {"account_id": "00000000-0000-0000-0000-000000000101", "debit": 100.00, "credit": 0.00},
            {"account_id": "00000000-0000-0000-0000-000000000102", "debit": 0.00, "credit": 90.00}
        ]'::jsonb
    ) $$,
    'P0001', -- Custom error or general exception? I'll use a specific message check if possible, or just check it fails.
    NULL,
    'Should fail for unbalanced entries'
);

-- RLS Tests
-- Setup: Second tenant and account
INSERT INTO tenants (id, name) VALUES ('00000000-0000-0000-0000-000000000002', 'Second Tenant');
INSERT INTO accounts (id, tenant_id, account_number, name, account_type_id, currency_code)
VALUES ('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000002', '1001', 'Cash T2', 1, 'USD');
INSERT INTO account_balances (account_id) VALUES ('00000000-0000-0000-0000-000000000201');

-- Create a non-superuser role to test RLS if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'test_rls_user') THEN
        CREATE ROLE test_rls_user LOGIN;
    END IF;
END
$$;

GRANT ALL ON ALL TABLES IN SCHEMA public TO test_rls_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO test_rls_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO test_rls_user;

-- Switch to test_rls_user
SET ROLE test_rls_user;
SELECT set_config('app.current_tenant_id', '00000000-0000-0000-0000-000000000001', true);

-- Test 8: RLS - Should fail when using account from another tenant
SELECT throws_ok(
    $$ SELECT create_journal_entry(
        'RLS-FAIL-1',
        'Invisible account',
        CURRENT_TIMESTAMP,
        '[
            {"account_id": "00000000-0000-0000-0000-000000000101", "debit": 100.00, "credit": 0.00},
            {"account_id": "00000000-0000-0000-0000-000000000201", "debit": 0.00, "credit": 100.00}
        ]'::jsonb
    ) $$,
    'One or more accounts are invalid, do not belong to the specified tenant, or are not accessible',
    'Should fail when using an account from another tenant'
);

-- Test 9: RLS - Should fail when trying to create entry for another tenant
-- (This fails because journal_entries RLS prevents inserting for another tenant)
SELECT throws_ok(
    $$ SELECT create_journal_entry(
        'RLS-FAIL-2',
        'Wrong tenant',
        CURRENT_TIMESTAMP,
        '[
            {"account_id": "00000000-0000-0000-0000-000000000201", "debit": 100.00, "credit": 0.00},
            {"account_id": "00000000-0000-0000-0000-000000000201", "debit": 0.00, "credit": 100.00}
        ]'::jsonb
    ) $$,
    'One or more accounts are invalid, do not belong to the specified tenant, or are not accessible',
    'Should fail when creating entry for another tenant'
);

-- Cleanup
SET ROLE postgres;

SELECT * FROM finish();
ROLLBACK;
