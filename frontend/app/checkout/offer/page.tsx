/**
 * Offer Selection Page - Step 1 of Checkout Flow
 *
 * This is the first step where users browse and select a marketing contract offer.
 * Offers are fetched from the backend and displayed as selectable cards.
 *
 * Flow:
 * 1. Component mounts and fetches offers from API
 * 2. User clicks an offer card to select it
 * 3. User clicks "Continue" to proceed to customer data entry
 * 4. Selected offer ID is saved to localStorage state
 *
 * Security considerations:
 * - Offer data comes directly from backend (trusted source)
 * - No user input validation needed (selection only)
 * - Prices displayed using Intl.NumberFormat (prevents XSS in number formatting)
 * - Selection is client-side only; backend validates offer exists when creating contract
 */

"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Stepper from "@/src/components/Stepper";
import { listOffers } from "@/src/lib/api";
import { saveCheckoutState, getCheckoutState } from "@/src/lib/checkout-state";
import type { Offer } from "@/src/lib/types";

export default function OfferSelectionPage() {
  const router = useRouter();
  
  // State management
  const [offers, setOffers] = useState<Offer[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  /**
   * Initialize selected offer from persisted state.
   * This allows the user to return to this page and see their previous selection.
   * Must be outside useEffect to avoid hydration mismatch.
   */
  const state = getCheckoutState();
  const [selectedOfferId, setSelectedOfferId] = useState<number | null>(
    state.offerId,
  );

  /**
   * Fetch offers from backend on component mount.
   * Empty dependency array ensures this runs once.
   */
  useEffect(() => {
    listOffers()
      .then((data) => {
        setOffers(data);
        setLoading(false);
      })
      .catch((err) => {
        // Display user-friendly error message
        setError(err.message || "Failed to load offers");
        setLoading(false);
      });
  }, []);

  /**
   * Handles the "Continue" button click.
   * Saves the selected offer ID to state and navigates to customer data page.
   *
   * Security: Only proceeds if an offer is selected (button is disabled otherwise)
   */
  const handleContinue = () => {
    if (selectedOfferId) {
      saveCheckoutState({ offerId: selectedOfferId });
      router.push("/checkout/customer");
    }
  };

  /**
   * Formats price in cents to currency string using browser's locale.
   *
   * @param cents - Price in cents (e.g., 1999 for $19.99)
   * @param currency - ISO 4217 currency code (e.g., "EUR", "USD")
   * @returns Formatted price string (e.g., "$19.99")
   *
   * Security: Intl.NumberFormat is safe from XSS as it doesn't execute scripts
   */
  const formatPrice = (cents: number, currency: string) => {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: currency,
    }).format(cents / 100);
  };

  // Loading state: Show spinner while fetching offers
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

  // Error state: Show error message if fetch failed
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

  // Main render: Display offers as selectable cards
  return (
    <div>
      <Stepper currentStep={1} />
      
      <div className="bg-white rounded-lg shadow-sm p-6">
        <h1 className="text-2xl font-bold mb-6">Select an Offer</h1>

        {/* Offer cards list */}
        <div className="space-y-4 mb-6">
          {offers.map((offer) => (
            <div
              key={offer.id}
              onClick={() => setSelectedOfferId(offer.id)}
              className={`border rounded-lg p-4 cursor-pointer transition-all ${
                selectedOfferId === offer.id
                  ? "border-blue-500 bg-blue-50" // Selected state
                  : "border-gray-300 hover:border-gray-400" // Default state
              }`}
            >
              <div className="flex justify-between items-start">
                {/* Offer details */}
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
                {/* Price display */}
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

        {/* Action buttons */}
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
