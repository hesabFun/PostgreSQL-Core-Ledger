-- Core Ledger Schema - Base Tables
-- Multi-tenant, multi-currency double-entry accounting system

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Tenants table
CREATE TABLE IF NOT EXISTS tenants
(
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP
);

-- Account Types (Asset, Liability, Equity, Revenue, Expense, etc.)
CREATE TABLE IF NOT EXISTS account_types
(
    id             SERIAL PRIMARY KEY,
    code           VARCHAR(50)  NOT NULL UNIQUE,
    name           VARCHAR(100) NOT NULL,
    normal_balance VARCHAR(10) CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    created_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Currencies table
CREATE TABLE IF NOT EXISTS currencies
(
    id         SERIAL PRIMARY KEY,
    code       VARCHAR(10)  NOT NULL UNIQUE,
    name       VARCHAR(100) NOT NULL,
    symbol     VARCHAR(10),
    precision  INT         DEFAULT 2 CHECK (precision >= 0),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Exchange Rates table
CREATE TABLE IF NOT EXISTS exchange_rates
(
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id     UUID           NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
    from_currency VARCHAR(10)    NOT NULL,
    to_currency   VARCHAR(10)    NOT NULL,
    rate          NUMERIC(20, 8) NOT NULL CHECK (rate > 0),
    source        VARCHAR(100)   NOT NULL,
    valid_from    TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP,
    valid_to      TIMESTAMPTZ,
    created_at    TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (from_currency) REFERENCES currencies (code),
    FOREIGN KEY (to_currency) REFERENCES currencies (code),
    CHECK (from_currency != to_currency)
);

-- Chart of Accounts
CREATE TABLE IF NOT EXISTS accounts
(
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id         UUID         NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
    account_number    VARCHAR(50)  NOT NULL,
    name              VARCHAR(255) NOT NULL,
    description       TEXT             DEFAULT NULL,
    account_type_id   INT          NOT NULL REFERENCES account_types (id),
    currency_code     VARCHAR(3)   NOT NULL REFERENCES currencies (code),
    parent_account_id UUID         REFERENCES accounts (id) ON DELETE SET NULL,
    is_active         BOOLEAN          DEFAULT TRUE,
    created_at        TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (tenant_id, account_number),
    CHECK (id != parent_account_id)
);

-- Journal Entries (transactions)
CREATE TABLE IF NOT EXISTS journal_entries
(
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id        UUID NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
    reference_number VARCHAR(100), -- Manual or external document number
    metadata         JSONB,        -- To store variable tax information for each country
    description      TEXT,
    entry_date       TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP,
    created_at       TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP
);

-- Journal Entry Lines (debit/credit entries)
CREATE TABLE IF NOT EXISTS journal_entry_lines
(
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journal_entry_id UUID NOT NULL REFERENCES journal_entries (id) ON DELETE CASCADE,
    account_id       UUID NOT NULL REFERENCES accounts (id),
    debit            NUMERIC(20, 4) CHECK (debit >= 0),
    credit           NUMERIC(20, 4) CHECK (credit >= 0),
    description      TEXT,
    created_at       TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT debit_credit_check CHECK (
        (debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0)
        )
);

-- Account Balances (for performance, denormalized)
CREATE TABLE IF NOT EXISTS account_balances
(
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id     UUID NOT NULL UNIQUE REFERENCES accounts (id) ON DELETE CASCADE,
    debit_balance  NUMERIC(20, 4)   DEFAULT 0 CHECK (debit_balance >= 0),
    credit_balance NUMERIC(20, 4)   DEFAULT 0 CHECK (credit_balance >= 0),
    created_at     TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP
);

-- Currency Conversion Log
CREATE TABLE IF NOT EXISTS currency_conversion_log
(
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id         UUID           NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
    source_account_id UUID           NOT NULL REFERENCES accounts (id),
    target_account_id UUID           NOT NULL REFERENCES accounts (id),
    source_amount     NUMERIC(20, 4) NOT NULL,
    exchange_rate     NUMERIC(20, 8) NOT NULL,
    target_amount     NUMERIC(20, 4) NOT NULL,
    journal_entry_id  UUID           NOT NULL REFERENCES journal_entries (id),
    created_at        TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP
);

-- Create function to update timestamp columns
CREATE OR REPLACE FUNCTION update_timestamp_column()
    RETURNS TRIGGER AS
$$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER trg_upd_tenants BEFORE UPDATE ON tenants FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trg_upd_account_types BEFORE UPDATE ON account_types FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trg_upd_currencies BEFORE UPDATE ON currencies FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trg_upd_exchange_rates BEFORE UPDATE ON exchange_rates FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trg_upd_accounts BEFORE UPDATE ON accounts FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trg_upd_journal_entries BEFORE UPDATE ON journal_entries FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trg_upd_account_balances BEFORE UPDATE ON account_balances FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();

-- Add comments to tables
COMMENT ON TABLE tenants IS 'Multi-tenant organization data';
COMMENT ON TABLE accounts IS 'Chart of accounts for each tenant, each account supports only one currency';
COMMENT ON TABLE journal_entries IS 'Double-entry journal transactions';
COMMENT ON TABLE journal_entry_lines IS 'Individual debit/credit entries within a journal transaction';
COMMENT ON TABLE account_balances IS 'Denormalized account balances for performance';
COMMENT ON TABLE exchange_rates IS 'Currency exchange rates with validity periods';
COMMENT ON TABLE currency_conversion_log IS 'Log of all currency conversions';

-- Enabling RLS on the chart of accounts
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
-- Create access policy (Tenant only sees its own data)
CREATE POLICY tenant_isolation_policy ON accounts
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

-- Set default tenant_id on new accounts
ALTER TABLE accounts
    ALTER COLUMN tenant_id
        SET DEFAULT current_setting('app.current_tenant_id')::uuid;
