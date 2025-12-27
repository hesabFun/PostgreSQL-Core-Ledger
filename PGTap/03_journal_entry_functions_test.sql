BEGIN;
SELECT plan(7);

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
SELECT has_function('create_journal_entry', ARRAY['uuid', 'character varying', 'text', 'timestamp with time zone', 'jsonb', 'jsonb']);

-- Test 2: Successful creation of a balanced entry
SELECT lives_ok(
    $$ SELECT create_journal_entry(
        '00000000-0000-0000-0000-000000000001',
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
        '00000000-0000-0000-0000-000000000001',
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

SELECT * FROM finish();
ROLLBACK;
