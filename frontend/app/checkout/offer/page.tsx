"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Stepper from "@/src/components/Stepper";
import { listOffers } from "@/src/lib/api";
import { saveCheckoutState, getCheckoutState } from "@/src/lib/checkout-state";
import type { Offer } from "@/src/lib/types";

export default function OfferSelectionPage() {
  const router = useRouter();
  const [offers, setOffers] = useState<Offer[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Initialize selected offer from state
  const state = getCheckoutState();
  const [selectedOfferId, setSelectedOfferId] = useState<number | null>(
    state.offerId,
  );

  useEffect(() => {
    // Fetch offers
    listOffers()
      .then((data) => {
        setOffers(data);
        setLoading(false);
      })
      .catch((err) => {
        setError(err.message || "Failed to load offers");
        setLoading(false);
      });
  }, []);

  const handleContinue = () => {
    if (selectedOfferId) {
      saveCheckoutState({ offerId: selectedOfferId });
      router.push("/checkout/customer");
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
        <Stepper currentStep={1} />
        <div className="flex justify-center items-center py-12">
          <div className="text-gray-600">Loading offers...</div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div>
        <Stepper currentStep={1} />
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
          <strong>Error:</strong> {error}
        </div>
      </div>
    );
  }

  return (
    <div>
      <Stepper currentStep={1} />
      
      <div className="bg-white rounded-lg shadow-sm p-6">
        <h1 className="text-2xl font-bold mb-6">Select an Offer</h1>

        <div className="space-y-4 mb-6">
          {offers.map((offer) => (
            <div
              key={offer.id}
              onClick={() => setSelectedOfferId(offer.id)}
              className={`border rounded-lg p-4 cursor-pointer transition-all ${
                selectedOfferId === offer.id
                  ? "border-blue-500 bg-blue-50"
                  : "border-gray-300 hover:border-gray-400"
              }`}
            >
              <div className="flex justify-between items-start">
                <div className="flex-1">
                  <h3 className="font-semibold text-lg">{offer.name}</h3>
                  {offer.description && (
                    <p className="text-gray-600 mt-1">{offer.description}</p>
                  )}
                  <div className="text-sm text-gray-500 mt-2">
                    <span>Billing: {offer.billing_period}</span>
                    {" • "}
                    <span>Min term: {offer.min_term_months} months</span>
                  </div>
                </div>
                <div className="ml-4 text-right">
                  <div className="text-2xl font-bold text-blue-600">
                    {formatPrice(offer.price_cents, offer.currency)}
                  </div>
                  <div className="text-sm text-gray-500">
                    per {offer.billing_period}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="flex justify-between">
          <button
            onClick={() => router.push("/")}
            className="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            onClick={handleContinue}
            disabled={!selectedOfferId}
            className={`px-6 py-2 rounded-lg ${
              selectedOfferId
                ? "bg-blue-600 text-white hover:bg-blue-700"
                : "bg-gray-300 text-gray-500 cursor-not-allowed"
            }`}
          >
            Continue
          </button>
        </div>
      </div>
    </div>
  );
}
