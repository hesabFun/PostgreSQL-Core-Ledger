
-- Setup: Create a tenant, account type, currency, and accounts
SELECT create_tenant('Tenant 1');
SELECT set_config('app.current_tenant_id', (SELECT id FROM tenants WHERE name = 'Tenant 1' LIMIT 1)::text, true);
INSERT INTO account_types (id, code, name, normal_balance) VALUES (1, 'ASSET', 'Asset', 'DEBIT');
INSERT INTO account_types (id, code, name, normal_balance) VALUES (2, 'REVENUE', 'Revenue', 'CREDIT');
INSERT INTO currencies (code, name, symbol) VALUES ('USD', 'US Dollar', '$');

-- Add a new transaction
DO
$$
    DECLARE
        v_cash_account_id  UUID;
        v_sales_account_id UUID;
    BEGIN
        PERFORM set_config('app.current_tenant_id', (SELECT id FROM tenants WHERE name = 'Tenant 1' LIMIT 1)::text, true);

        v_cash_account_id := create_account('1001', 'Cash', 1, 'USD');
        v_sales_account_id := create_account('4001', 'Sales', 1, 'USD');

        PERFORM create_journal_entry(
                       'REF-001',
                       'Initial Sale',
                       CURRENT_TIMESTAMP,
                       jsonb_build_array(
                               jsonb_build_object(
                                       'account_id', v_cash_account_id,
                                       'debit', 100.00,
                                       'credit', 0.00,
                                       'description', 'Cash in'
                               ),
                               jsonb_build_object(
                                       'account_id', v_sales_account_id,
                                       'debit', 0.00,
                                       'credit', 100.00,
                                       'description', 'Sales revenue'
                               )
                       )
               );
    END
$$;