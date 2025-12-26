// API types matching backend schemas

export interface Offer {
  id: number;
  code: string;
  name: string;
  description: string | null;
  currency: string;
  price_cents: number;
  billing_period: string;
  min_term_months: number;
  notice_period_days: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface CounterpartyCreate {
  type: "person" | "company";
  name: string;
  street: string;
  postal_code: string;
  city: string;
  country: string;
  email: string;
}

export interface Counterparty extends CounterpartyCreate {
  id: number;
  created_at: string;
  updated_at: string;
}

export interface ContractDraftCreate {
  counterparty_id: number;
  offer_id: number;
}

export interface Contract {
  id: string;
  status: string;
  counterparty_id: number;
  offer_id: number;
  draft_pdf_available: boolean;
  counterparty?: {
    id: number;
    name: string;
    email: string;
    street: string;
    postal_code: string;
    city: string;
    country: string;
  };
  offer?: {
    id: number;
    code: string;
    name: string;
    price_cents: number;
    currency: string;
    billing_period: string;
  };
  created_at: string;
  updated_at: string;
}

export interface SigningStartResponse {
  contract_id: string;
  status: string;
  provider: string;
  provider_envelope_id: string;
  signing_url: string;
}
