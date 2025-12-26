import { describe, it, expect, vi, beforeEach } from "vitest";
import {
  listOffers,
  createCounterparty,
  createContractDraft,
  getContract,
  startSigning,
  getDraftPdfUrl,
  getSignedPdfUrl,
} from "../lib/api";

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch as unknown as typeof fetch;

describe("API Client", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("should list offers", async () => {
    const mockOffers = [
      {
        id: 1,
        name: "Test Offer",
        price_cents: 1000,
        currency: "EUR",
      },
    ];

    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => mockOffers,
    });

    const offers = await listOffers();
    expect(offers).toEqual(mockOffers);
    expect(mockFetch).toHaveBeenCalledWith(
      "http://localhost:8000/offers",
      expect.any(Object),
    );
  });

  it("should create counterparty", async () => {
    const mockCounterparty = {
      id: 1,
      type: "person",
      name: "John Doe",
      street: "123 Main St",
      postal_code: "12345",
      city: "Berlin",
      country: "DE",
      email: "john@example.com",
      created_at: "2024-01-01T00:00:00Z",
      updated_at: "2024-01-01T00:00:00Z",
    };

    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => mockCounterparty,
    });

    const result = await createCounterparty({
      type: "person",
      name: "John Doe",
      street: "123 Main St",
      postal_code: "12345",
      city: "Berlin",
      country: "DE",
      email: "john@example.com",
    });

    expect(result).toEqual(mockCounterparty);
  });

  it("should create contract draft", async () => {
    const mockContract = {
      id: "contract-123",
      status: "draft",
      counterparty_id: 1,
      offer_id: 1,
      draft_pdf_available: true,
      created_at: "2024-01-01T00:00:00Z",
      updated_at: "2024-01-01T00:00:00Z",
    };

    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => mockContract,
    });

    const result = await createContractDraft(1, 1);
    expect(result).toEqual(mockContract);
  });

  it("should get contract by id", async () => {
    const mockContract = {
      id: "contract-123",
      status: "signed",
      counterparty_id: 1,
      offer_id: 1,
      draft_pdf_available: true,
      created_at: "2024-01-01T00:00:00Z",
      updated_at: "2024-01-01T00:00:00Z",
    };

    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => mockContract,
    });

    const result = await getContract("contract-123");
    expect(result).toEqual(mockContract);
  });

  it("should start signing", async () => {
    const mockSigningResponse = {
      contract_id: "contract-123",
      status: "awaiting_signature",
      provider: "stub",
      provider_envelope_id: "env-123",
      signing_url: "https://example.com/sign",
    };

    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => mockSigningResponse,
    });

    const result = await startSigning("contract-123");
    expect(result).toEqual(mockSigningResponse);
  });

  it("should generate draft PDF URL", () => {
    const url = getDraftPdfUrl("contract-123");
    expect(url).toBe("http://localhost:8000/contracts/contract-123/draft-pdf");
  });

  it("should generate signed PDF URL", () => {
    const url = getSignedPdfUrl("contract-123");
    expect(url).toBe(
      "http://localhost:8000/contracts/contract-123/signed-pdf",
    );
  });

  it("should handle API errors", async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      status: 404,
      text: async () => JSON.stringify({ detail: "Not found" }),
    });

    await expect(listOffers()).rejects.toThrow("Not found");
  });
});
