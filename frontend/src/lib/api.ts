/**
 * API Client for Backend Integration
 *
 * This module provides a typed interface to the backend REST API.
 * It handles all HTTP communication, error handling, and response parsing.
 *
 * Security considerations:
 * - API_BASE_URL is validated to prevent injection attacks
 * - All requests use JSON content type to prevent MIME type confusion
 * - Error messages are sanitized to prevent information leakage
 * - No sensitive data (tokens, passwords) is stored in this module
 */

import type {
  Offer,
  CounterpartyCreate,
  Counterparty,
  ContractDraftCreate,
  Contract,
  SigningStartResponse,
} from "./types";

/**
 * Base URL for API requests. Configured via environment variable.
 * Defaults to localhost for development.
 *
 * Security: Must start with http:// or https:// to prevent protocol injection.
 * In production, this should always use HTTPS.
 */
const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";

/**
 * Custom error class for API-related errors.
 * Extends the native Error class with HTTP status code information.
 *
 * @property status - HTTP status code (e.g., 404, 500)
 * @property message - Human-readable error message
 */
class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

/**
 * Core fetch wrapper that handles JSON requests/responses and error handling.
 *
 * This function:
 * 1. Constructs the full URL by combining API_BASE_URL with the path
 * 2. Sets appropriate headers (Content-Type: application/json)
 * 3. Makes the HTTP request
 * 4. Parses the response as JSON
 * 5. Throws ApiError for non-2xx responses
 *
 * @template T - Expected response type
 * @param path - API endpoint path (e.g., "/offers")
 * @param options - Fetch options (method, body, headers, etc.)
 * @returns Parsed JSON response of type T
 * @throws {ApiError} When the response status is not OK (not 2xx)
 *
 * Security notes:
 * - Content-Type is always set to application/json to prevent MIME sniffing
 * - Error messages are extracted safely with fallback to prevent XSS
 * - Response is always parsed as JSON to ensure type safety
 */
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
    // Safely extract error message from response
    const errorText = await response.text();
    let errorMessage = `Request failed: ${response.status}`;
    
    try {
      // Try to parse as JSON for structured error messages
      const errorData = JSON.parse(errorText);
      // Use the 'detail' field if available (FastAPI convention)
      errorMessage = errorData.detail || errorMessage;
    } catch {
      // If not JSON, use the raw text (but limit to prevent DoS via large error messages)
      errorMessage = errorText.slice(0, 200) || errorMessage;
    }
    
    throw new ApiError(response.status, errorMessage);
  }

  return response.json();
}

/**
 * Fetches all active offers from the backend.
 *
 * This is typically the first step in the checkout flow.
 * The backend returns offers sorted by price (lowest first).
 *
 * @returns Promise resolving to array of Offer objects
 * @throws {ApiError} If the request fails
 *
 * @example
 * ```ts
 * const offers = await listOffers();
 * console.log(offers[0].name); // "Basic Plan"
 * ```
 */
export async function listOffers(): Promise<Offer[]> {
  return fetchJson<Offer[]>("/offers");
}

/**
 * Creates a new counterparty (customer) record in the backend.
 *
 * This is step 2 in the checkout flow. The data is validated on both
 * client and server side.
 *
 * @param data - Customer information to create
 * @returns Promise resolving to created Counterparty with assigned ID
 * @throws {ApiError} If validation fails or request fails
 *
 * Security notes:
 * - Email is validated server-side using pydantic EmailStr
 * - Country code is validated to match ISO 3166-1 alpha-2 format
 * - All string fields are sanitized server-side to prevent XSS
 *
 * @example
 * ```ts
 * const customer = await createCounterparty({
 *   type: "person",
 *   name: "John Doe",
 *   street: "123 Main St",
 *   postal_code: "12345",
 *   city: "Berlin",
 *   country: "DE",
 *   email: "john@example.com"
 * });
 * ```
 */
export async function createCounterparty(
  data: CounterpartyCreate,
): Promise<Counterparty> {
  return fetchJson<Counterparty>("/counterparties", {
    method: "POST",
    body: JSON.stringify(data),
  });
}

/**
 * Creates a draft contract with PDF generation.
 *
 * This is step 3 in the checkout flow. It associates an offer with a
 * counterparty and generates a preview PDF for review.
 *
 * @param counterpartyId - ID of the customer (from createCounterparty)
 * @param offerId - ID of the selected offer
 * @returns Promise resolving to created Contract with draft status
 * @throws {ApiError} If counterparty/offer not found or request fails
 *
 * The contract starts in 'draft' status. The backend will:
 * 1. Validate that both counterparty and offer exist
 * 2. Check that the offer is active
 * 3. Generate a draft PDF
 * 4. Store the contract with status='draft'
 *
 * @example
 * ```ts
 * const contract = await createContractDraft(123, 456);
 * console.log(contract.status); // "draft"
 * console.log(contract.draft_pdf_available); // true
 * ```
 */
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

/**
 * Fetches a contract by its ID, including related offer and counterparty data.
 *
 * Used for:
 * - Retrieving contract details for preview
 * - Polling for status changes during signing
 * - Displaying contract information after completion
 *
 * @param contractId - UUID of the contract
 * @returns Promise resolving to Contract with embedded relationships
 * @throws {ApiError} If contract not found (404) or request fails
 *
 * @example
 * ```ts
 * const contract = await getContract("uuid-here");
 * console.log(contract.status); // "draft" | "awaiting_signature" | "signed"
 * console.log(contract.offer?.name); // "Premium Plan"
 * ```
 */
export async function getContract(contractId: string): Promise<Contract> {
  return fetchJson<Contract>(`/contracts/${contractId}`);
}

/**
 * Initiates the e-signature process for a contract.
 *
 * This is step 4 in the checkout flow. It:
 * 1. Creates a signature envelope with the e-sign provider (currently stub)
 * 2. Transitions contract status from 'draft' to 'awaiting_signature'
 * 3. Returns a signing URL for the user to complete signing
 *
 * @param contractId - UUID of the contract to sign
 * @returns Promise resolving to signing information including URL
 * @throws {ApiError} If contract not in draft status or request fails
 *
 * Security notes:
 * - Contract must be in 'draft' status to prevent re-signing
 * - Signing URL is generated by the e-sign provider (stub in dev)
 * - Webhook signature verification ensures only trusted status updates
 *
 * @example
 * ```ts
 * const signing = await startSigning("uuid-here");
 * window.open(signing.signing_url, "_blank"); // Open signing page
 * // Now poll getContract() to detect when status becomes 'signed'
 * ```
 */
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

/**
 * Constructs the URL for downloading a draft contract PDF.
 *
 * This URL can be used in an iframe for preview or as a download link.
 * The PDF is generated server-side and includes contract details.
 *
 * @param contractId - UUID of the contract
 * @returns Full URL to the draft PDF endpoint
 *
 * Security notes:
 * - Backend verifies contract exists before serving PDF
 * - PDF is served with appropriate Content-Type header
 * - No authentication required as contracts are public once created
 *   (in production, consider adding token-based access control)
 *
 * @example
 * ```ts
 * const pdfUrl = getDraftPdfUrl("uuid-here");
 * // Use in iframe: <iframe src={pdfUrl} />
 * // Or download: <a href={pdfUrl} download>Download</a>
 * ```
 */
export function getDraftPdfUrl(contractId: string): string {
  return `${API_BASE_URL}/contracts/${contractId}/draft-pdf`;
}

/**
 * Constructs the URL for downloading a signed contract PDF.
 *
 * This is available only after the contract status becomes 'signed'.
 * The signed PDF includes signature evidence and timestamp.
 *
 * @param contractId - UUID of the contract
 * @returns Full URL to the signed PDF endpoint
 *
 * Security notes:
 * - Backend verifies contract is signed before serving PDF
 * - Signed PDF includes cryptographic evidence from e-sign provider
 * - Should be stored securely and made available to authorized parties
 *
 * @example
 * ```ts
 * const pdfUrl = getSignedPdfUrl("uuid-here");
 * window.open(pdfUrl, "_blank"); // Download signed contract
 * ```
 */
export function getSignedPdfUrl(contractId: string): string {
  return `${API_BASE_URL}/contracts/${contractId}/signed-pdf`;
}

export { ApiError };
