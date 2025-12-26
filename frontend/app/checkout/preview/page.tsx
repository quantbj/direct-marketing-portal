/**
 * Contract Preview Page - Step 3 of Checkout Flow
 *
 * This page displays the contract details and draft PDF for user review.
 * It creates a contract draft (or retrieves an existing one) and shows:
 * - Selected offer summary
 * - Customer information summary
 * - Embedded PDF preview of the contract
 *
 * Flow:
 * 1. User arrives from customer data page
 * 2. Check if contract already exists in state (from page refresh)
 * 3. If not, create new contract draft via API
 * 4. Display contract summary and PDF
 * 5. User clicks "Start Signing" to proceed to e-signature
 *
 * Security considerations:
 * - Guard ensures user has completed previous steps (offer + customer)
 * - Contract ID is stored client-side but validated server-side
 * - PDF is served directly from backend (not stored in browser)
 * - iframe sandbox could be added for extra PDF security (current: none)
 * - All data displayed is from backend (trusted source)
 */

"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Stepper from "@/src/components/Stepper";
import { createContractDraft, getDraftPdfUrl, getContract } from "@/src/lib/api";
import { saveCheckoutState, getCheckoutState } from "@/src/lib/checkout-state";
import type { Contract } from "@/src/lib/types";

export default function PreviewContractPage() {
  const router = useRouter();
  
  // State management
  const [contract, setContract] = useState<Contract | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  /**
   * Initialize or retrieve contract on component mount.
   *
   * This effect handles two scenarios:
   * 1. First visit: Creates a new contract draft
   * 2. Returning visit (page refresh): Fetches existing contract
   *
   * The contract creation associates the selected offer with the customer
   * and generates a PDF document for preview.
   */
  useEffect(() => {
    const initializeContract = async () => {
      const state = getCheckoutState();

      /**
       * Guard: Ensure user has completed previous steps.
       * If offer or customer is missing, redirect to start of flow.
       * This prevents incomplete checkouts and API errors.
       */
      if (!state.offerId || !state.counterpartyId) {
        router.push("/checkout/offer");
        return;
      }

      /**
       * If we already have a contract ID (from previous visit or page refresh),
       * fetch the full contract details instead of creating a new one.
       * This ensures idempotency and prevents duplicate contracts.
       */
      if (state.contractId) {
        try {
          const existingContract = await getContract(state.contractId);
          setContract(existingContract);
          setLoading(false);
          return;
        } catch (err: unknown) {
          // If fetch fails (contract deleted, network error, etc.),
          // fall through to create a new draft
          console.error("Failed to fetch existing contract:", err);
        }
      }

      /**
       * Create a new contract draft.
       * This calls the backend to:
       * 1. Validate offer and customer exist
       * 2. Create contract record with status='draft'
       * 3. Generate PDF with contract details
       * 4. Return contract with embedded offer/customer data
       */
      try {
        const newContract = await createContractDraft(
          state.counterpartyId,
          state.offerId,
        );
        setContract(newContract);
        // Save contract ID for page refresh resilience
        saveCheckoutState({ contractId: newContract.id });
        setLoading(false);
      } catch (err: unknown) {
        setError(
          err instanceof Error ? err.message : "Failed to create contract draft",
        );
        setLoading(false);
      }
    };

    initializeContract();
  }, [router]);

  /**
   * Navigates to the signing page.
   * Only enabled when contract is loaded.
   */
  const handleStartSigning = () => {
    if (contract) {
      router.push("/checkout/sign");
    }
  };

  /**
   * Formats price in cents to currency string.
   * Same implementation as offer page for consistency.
   */
  const formatPrice = (cents: number, currency: string) => {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: currency,
    }).format(cents / 100);
  };

  // Loading state: Show while creating/fetching contract
  if (loading) {
    return (
      <div>
        <Stepper currentStep={3} />
        <div className="flex justify-center items-center py-12">
          <div className="text-gray-600">Creating contract draft...</div>
        </div>
      </div>
    );
  }

  // Error state: Show if contract creation failed
  if (error) {
    return (
      <div>
        <Stepper currentStep={3} />
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
          <strong>Error:</strong> {error}
        </div>
        <div className="mt-4">
          <button
            onClick={() => router.push("/checkout/customer")}
            className="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Back
          </button>
        </div>
      </div>
    );
  }

  // Guard: Should not happen, but handle null contract
  if (!contract) {
    return null;
  }

  // Main render: Display contract preview
  return (
    <div>
      <Stepper currentStep={3} />

      <div className="bg-white rounded-lg shadow-sm p-6">
        <h1 className="text-2xl font-bold mb-6">Preview Contract</h1>

        {/* Offer Summary Section */}
        {contract.offer && (
          <div className="mb-6 p-4 bg-gray-50 rounded-lg">
            <h2 className="font-semibold text-lg mb-2">Offer</h2>
            <div className="text-gray-700">
              <div className="mb-1">
                <span className="font-medium">{contract.offer.name}</span>
              </div>
              <div>
                Price:{" "}
                {formatPrice(
                  contract.offer.price_cents,
                  contract.offer.currency,
                )}{" "}
                per {contract.offer.billing_period}
              </div>
            </div>
          </div>
        )}

        {/* Customer Summary Section */}
        {contract.counterparty && (
          <div className="mb-6 p-4 bg-gray-50 rounded-lg">
            <h2 className="font-semibold text-lg mb-2">Customer</h2>
            <div className="text-gray-700">
              <div>{contract.counterparty.name}</div>
              <div>{contract.counterparty.street}</div>
              <div>
                {contract.counterparty.postal_code} {contract.counterparty.city}
                , {contract.counterparty.country}
              </div>
              <div className="mt-1">{contract.counterparty.email}</div>
            </div>
          </div>
        )}

        {/* PDF Preview Section */}
        <div className="mb-6">
          <h2 className="font-semibold text-lg mb-3">Contract Document</h2>
          <div className="border border-gray-300 rounded-lg overflow-hidden">
            {/*
              Security note: iframe loads PDF from backend server.
              - PDF is dynamically generated per contract
              - Backend validates contract exists before serving
              - Consider adding sandbox attribute for extra security:
                sandbox="allow-same-origin"
              - Current implementation trusts backend PDF generation
            */}
            <iframe
              src={getDraftPdfUrl(contract.id)}
              className="w-full h-[600px]"
              title="Contract Draft PDF"
            />
          </div>
        </div>

        {/* Action buttons */}
        <div className="flex justify-between">
          <button
            onClick={() => router.push("/checkout/customer")}
            className="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Back
          </button>
          <button
            onClick={handleStartSigning}
            className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            Start Signing
          </button>
        </div>
      </div>
    </div>
  );
}
