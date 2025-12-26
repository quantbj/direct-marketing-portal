// API client for backend integration

import type {
  Offer,
  CounterpartyCreate,
  Counterparty,
  ContractDraftCreate,
  Contract,
  SigningStartResponse,
} from "./types";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";

class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

async function fetchJson<T>(
  path: string,
  options?: RequestInit,
): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...options?.headers,
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    let errorMessage = `Request failed: ${response.status}`;
    try {
      const errorData = JSON.parse(errorText);
      errorMessage = errorData.detail || errorMessage;
    } catch {
      errorMessage = errorText || errorMessage;
    }
    throw new ApiError(response.status, errorMessage);
  }

  return response.json();
}

export async function listOffers(): Promise<Offer[]> {
  return fetchJson<Offer[]>("/offers");
}

export async function createCounterparty(
  data: CounterpartyCreate,
): Promise<Counterparty> {
  return fetchJson<Counterparty>("/counterparties", {
    method: "POST",
    body: JSON.stringify(data),
  });
}

export async function createContractDraft(
  counterpartyId: number,
  offerId: number,
): Promise<Contract> {
  const data: ContractDraftCreate = {
    counterparty_id: counterpartyId,
    offer_id: offerId,
  };
  return fetchJson<Contract>("/contracts/draft", {
    method: "POST",
    body: JSON.stringify(data),
  });
}

export async function getContract(contractId: string): Promise<Contract> {
  return fetchJson<Contract>(`/contracts/${contractId}`);
}

export async function startSigning(
  contractId: string,
): Promise<SigningStartResponse> {
  return fetchJson<SigningStartResponse>(
    `/contracts/${contractId}/signing/start`,
    {
      method: "POST",
      body: JSON.stringify({}),
    },
  );
}

export function getDraftPdfUrl(contractId: string): string {
  return `${API_BASE_URL}/contracts/${contractId}/draft-pdf`;
}

export function getSignedPdfUrl(contractId: string): string {
  return `${API_BASE_URL}/contracts/${contractId}/signed-pdf`;
}

export { ApiError };
