BEGIN;
SELECT plan(6);

-- Setup: Create a tenant, account type, and currency
INSERT INTO tenants (name) VALUES ('Test Tenant');
SELECT set_config('app.current_tenant_id', (SELECT id FROM tenants WHERE name = 'Test Tenant' LIMIT 1)::text, true);

INSERT INTO account_types (code, name, normal_balance) VALUES ('ASSET', 'Asset', 'DEBIT');
INSERT INTO currencies (code, name, symbol) VALUES ('USD', 'US Dollar', '$');

-- Check if function exists
SELECT has_function('create_account', ARRAY['character varying', 'character varying', 'integer', 'character varying', 'text', 'uuid']);

-- Test creating an account
SELECT lives_ok(
    $$ SELECT create_account(
        '1001',
        'Cash',
        (SELECT id FROM account_types WHERE code = 'ASSET' LIMIT 1),
        'USD'
    ) $$,
    'create_account should execute successfully'
);

-- Verify account was created
SELECT is(
    (SELECT count(*) FROM accounts WHERE account_number = '1001' AND tenant_id = (SELECT id FROM tenants WHERE name = 'Test Tenant' LIMIT 1)),
    1::bigint,
    'Account should exist after creation'
);

-- Verify account details
SELECT is(
    (SELECT name FROM accounts WHERE account_number = '1001' AND tenant_id = (SELECT id FROM tenants WHERE name = 'Test Tenant' LIMIT 1)),
    'Cash',
    'Account name should match'
);

-- Verify account balance was initialized
SELECT is(
    (SELECT count(*) FROM account_balances ab JOIN accounts a ON ab.account_id = a.id WHERE a.account_number = '1001' AND a.tenant_id = (SELECT id FROM tenants WHERE name = 'Test Tenant' LIMIT 1)),
    1::bigint,
    'Account balance should be initialized'
);

SELECT is(
    (SELECT debit_balance FROM account_balances ab JOIN accounts a ON ab.account_id = a.id WHERE a.account_number = '1001' AND a.tenant_id = (SELECT id FROM tenants WHERE name = 'Test Tenant' LIMIT 1)),
    0.0000::numeric,
    'Initial debit balance should be 0'
);

SELECT * FROM finish();
ROLLBACK;
