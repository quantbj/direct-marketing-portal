"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import Stepper from "@/src/components/Stepper";
import {
  startSigning,
  getContract,
  getSignedPdfUrl,
} from "@/src/lib/api";
import { getCheckoutState, clearCheckoutState } from "@/src/lib/checkout-state";
import type { Contract, SigningStartResponse } from "@/src/lib/types";

export default function SignPage() {
  const router = useRouter();
  const [signingData, setSigningData] = useState<SigningStartResponse | null>(
    null,
  );
  const [contract, setContract] = useState<Contract | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [polling, setPolling] = useState(false);
  const pollingTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const pollCountRef = useRef(0);
  const pollContractRef = useRef<((contractId: string) => Promise<void>) | null>(null);

  useEffect(() => {
    const pollContract = async (contractId: string) => {
      try {
        const contractData = await getContract(contractId);
        setContract(contractData);

        // Stop polling if signed or after 2 minutes (24 polls * 5 seconds)
        if (contractData.status === "signed") {
          setPolling(false);
          return;
        }

        pollCountRef.current += 1;
        if (pollCountRef.current >= 24) {
          setPolling(false);
          setError(
            "Signing process is taking longer than expected. Please check back later.",
          );
          return;
        }

        // Schedule next poll
        pollingTimeoutRef.current = setTimeout(
          () => pollContract(contractId),
          5000,
        );
      } catch (err: unknown) {
        console.error("Polling error:", err);
        // Continue polling even on error
        pollCountRef.current += 1;
        if (pollCountRef.current < 24) {
          pollingTimeoutRef.current = setTimeout(
            () => pollContract(contractId),
            5000,
          );
        }
      }
    };
    
    pollContractRef.current = pollContract;
    const initializeSigning = async () => {
      const state = getCheckoutState();

      // Validate prerequisites
      if (!state.contractId) {
        router.push("/checkout/offer");
        return;
      }

      try {
        const signingResponse = await startSigning(state.contractId);
        setSigningData(signingResponse);
        setLoading(false);
        
        // Start polling immediately
        setPolling(true);
        pollCountRef.current = 0;
        if (pollContractRef.current) {
          pollContractRef.current(state.contractId);
        }
      } catch (err: unknown) {
        setError(
          err instanceof Error ? err.message : "Failed to start signing process",
        );
        setLoading(false);
      }
    };

    initializeSigning();

    // Cleanup on unmount
    return () => {
      if (pollingTimeoutRef.current) {
        clearTimeout(pollingTimeoutRef.current);
      }
    };
  }, [router]);

  const handleStartOver = () => {
    clearCheckoutState();
    router.push("/checkout/offer");
  };

  const handleDownloadSignedPdf = () => {
    if (contract) {
      window.open(getSignedPdfUrl(contract.id), "_blank");
    }
  };

  if (loading) {
    return (
      <div>
        <Stepper currentStep={4} />
        <div className="flex justify-center items-center py-12">
          <div className="text-gray-600">Initializing signing process...</div>
        </div>
      </div>
    );
  }

  if (error && !signingData) {
    return (
      <div>
        <Stepper currentStep={4} />
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
          <strong>Error:</strong> {error}
        </div>
        <div className="mt-4">
          <button
            onClick={() => router.push("/checkout/preview")}
            className="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Back
          </button>
        </div>
      </div>
    );
  }

  const isSigned = contract?.status === "signed";
  const isAwaitingSignature = contract?.status === "awaiting_signature";

  return (
    <div>
      <Stepper currentStep={4} />

      <div className="bg-white rounded-lg shadow-sm p-6">
        <h1 className="text-2xl font-bold mb-6">Sign Contract</h1>

        {/* Signing URL */}
        {signingData && (
          <div className="mb-6 p-4 bg-blue-50 rounded-lg">
            <h2 className="font-semibold text-lg mb-3">Ready to Sign</h2>
            <p className="text-gray-700 mb-4">
              Click the button below to open the signing page in a new tab.
            </p>
            <button
              onClick={() => window.open(signingData.signing_url, "_blank")}
              className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
            >
              Open Signing Page
            </button>
          </div>
        )}

        {/* Status Display */}
        <div className="mb-6 p-4 bg-gray-50 rounded-lg">
          <h2 className="font-semibold text-lg mb-3">Contract Status</h2>
          
          <div className="flex items-center space-x-3">
            {polling && (
              <div className="w-5 h-5 border-2 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
            )}
            <div>
              <span className="font-medium">Status: </span>
              <span
                className={`inline-block px-3 py-1 rounded ${
                  isSigned
                    ? "bg-green-100 text-green-800"
                    : isAwaitingSignature
                      ? "bg-yellow-100 text-yellow-800"
                      : "bg-gray-100 text-gray-800"
                }`}
              >
                {contract?.status || signingData?.status || "unknown"}
              </span>
            </div>
          </div>

          {polling && (
            <p className="text-sm text-gray-600 mt-2">
              Checking for signature completion...
            </p>
          )}
        </div>

        {/* Success Message */}
        {isSigned && (
          <div className="mb-6 p-4 bg-green-50 border border-green-200 rounded-lg">
            <h2 className="font-semibold text-lg text-green-800 mb-2">
              ✓ Contract Signed Successfully!
            </h2>
            <p className="text-green-700 mb-4">
              Your contract has been signed and is now active.
            </p>
            <button
              onClick={handleDownloadSignedPdf}
              className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
            >
              Download Signed PDF
            </button>
          </div>
        )}

        {/* Stub Webhook Hint (for dev/staging) */}
        {isAwaitingSignature && process.env.NODE_ENV !== "production" && (
          <div className="mb-6 p-3 bg-yellow-50 border border-yellow-200 rounded text-sm text-yellow-800">
            <strong>Dev Note:</strong> To simulate signing completion, the
            operator can trigger the stub webhook endpoint.
          </div>
        )}

        {/* Timeout Warning */}
        {error && (
          <div className="mb-6 p-4 bg-orange-50 border border-orange-200 text-orange-700 rounded">
            {error}
          </div>
        )}

        <div className="flex justify-between">
          <button
            onClick={handleStartOver}
            className="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Start Over
          </button>
          {!isSigned && (
            <button
              onClick={() => router.push("/checkout/preview")}
              className="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Back to Preview
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
