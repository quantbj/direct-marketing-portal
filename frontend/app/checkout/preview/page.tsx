"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Stepper from "@/src/components/Stepper";
import { createContractDraft, getDraftPdfUrl, getContract } from "@/src/lib/api";
import { saveCheckoutState, getCheckoutState } from "@/src/lib/checkout-state";
import type { Contract } from "@/src/lib/types";

export default function PreviewContractPage() {
  const router = useRouter();
  const [contract, setContract] = useState<Contract | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const initializeContract = async () => {
      const state = getCheckoutState();

      // Validate prerequisites
      if (!state.offerId || !state.counterpartyId) {
        router.push("/checkout/offer");
        return;
      }

      // If we already have a contract, fetch its full details
      if (state.contractId) {
        try {
          const existingContract = await getContract(state.contractId);
          setContract(existingContract);
          setLoading(false);
          return;
        } catch (err: unknown) {
          // If fetch fails, create a new draft below
          console.error("Failed to fetch existing contract:", err);
        }
      }

      // Create contract draft
      try {
        const newContract = await createContractDraft(
          state.counterpartyId,
          state.offerId,
        );
        setContract(newContract);
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

  const handleStartSigning = () => {
    if (contract) {
      router.push("/checkout/sign");
    }
  };

  const formatPrice = (cents: number, currency: string) => {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: currency,
    }).format(cents / 100);
  };

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

  if (!contract) {
    return null;
  }

  return (
    <div>
      <Stepper currentStep={3} />

      <div className="bg-white rounded-lg shadow-sm p-6">
        <h1 className="text-2xl font-bold mb-6">Preview Contract</h1>

        {/* Offer Summary */}
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

        {/* Counterparty Summary */}
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

        {/* PDF Preview */}
        <div className="mb-6">
          <h2 className="font-semibold text-lg mb-3">Contract Document</h2>
          <div className="border border-gray-300 rounded-lg overflow-hidden">
            <iframe
              src={getDraftPdfUrl(contract.id)}
              className="w-full h-[600px]"
              title="Contract Draft PDF"
            />
          </div>
        </div>

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
