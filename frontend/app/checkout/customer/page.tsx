/**
 * Customer Data Page - Step 2 of Checkout Flow
 *
 * This page collects customer information required for contract creation.
 * All data is validated client-side for UX, then re-validated server-side for security.
 *
 * Flow:
 * 1. User arrives from offer selection (validated on mount)
 * 2. User fills form fields with personal/company information
 * 3. Client-side validation provides immediate feedback
 * 4. On submit, data is sent to backend API
 * 5. Backend creates counterparty record and returns ID
 * 6. ID is saved to state and user proceeds to preview
 *
 * Security considerations:
 * - All inputs are controlled components (React state)
 * - Client validation is for UX only; backend re-validates everything
 * - Email validated with regex (client) and pydantic EmailStr (server)
 * - Country code enforced as 2 uppercase letters (ISO 3166-1 alpha-2)
 * - No SQL injection risk (backend uses SQLAlchemy ORM with parameterized queries)
 * - XSS prevented by React's auto-escaping and backend sanitization
 * - Trimming whitespace prevents invisible character attacks
 */

"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Stepper from "@/src/components/Stepper";
import { createCounterparty } from "@/src/lib/api";
import { saveCheckoutState, getCheckoutState } from "@/src/lib/checkout-state";
import type { CounterpartyCreate } from "@/src/lib/types";

export default function CustomerDataPage() {
  const router = useRouter();
  
  // UI state
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  /**
   * Form data matching the CounterpartyCreate schema.
   * Initialized with sensible defaults:
   * - type: "person" (most common case)
   * - country: "DE" (Germany, as this is a German marketing platform)
   */
  const [formData, setFormData] = useState<CounterpartyCreate>({
    type: "person",
    name: "",
    street: "",
    postal_code: "",
    city: "",
    country: "DE",
    email: "",
  });

  /**
   * Guard: Redirect to offer selection if no offer is selected.
   * This ensures users follow the correct flow and prevents incomplete checkouts.
   */
  useEffect(() => {
    const state = getCheckoutState();
    if (!state.offerId) {
      router.push("/checkout/offer");
    }
  }, [router]);

  /**
   * Handles input changes for all form fields.
   * Updates the form data state as user types.
   *
   * Security: Input is stored in state but not executed or rendered unsafely.
   * React auto-escapes all text content to prevent XSS.
   */
  const handleChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>,
  ) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  /**
   * Validates form data client-side for immediate user feedback.
   *
   * Validation rules:
   * - All text fields must be non-empty after trimming whitespace
   * - Email must match basic format: something@domain.extension
   * - Country must be exactly 2 uppercase letters (ISO 3166-1 alpha-2)
   *
   * @returns true if all validation passes, false otherwise
   *
   * Security notes:
   * - Trimming prevents invisible character attacks
   * - Email regex is basic (prevents obvious typos, not foolproof)
   * - Server performs stricter validation (pydantic EmailStr)
   * - Country format prevents injection of longer strings
   */
  const validateForm = (): boolean => {
    // Required field checks (trim to prevent whitespace-only values)
    if (!formData.name.trim()) return false;
    if (!formData.street.trim()) return false;
    if (!formData.postal_code.trim()) return false;
    if (!formData.city.trim()) return false;
    if (!formData.email.trim()) return false;
    
    // Country code format: exactly 2 uppercase letters
    if (!/^[A-Z]{2}$/.test(formData.country)) return false;
    
    // Email format: basic check for user@domain.ext
    // Server will do stricter validation with pydantic EmailStr
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) return false;
    
    return true;
  };

  /**
   * Handles form submission.
   *
   * Flow:
   * 1. Prevent default form submission (page reload)
   * 2. Validate form data
   * 3. Set loading state and clear previous errors
   * 4. Send data to backend API
   * 5. On success: save counterparty ID to state and navigate to preview
   * 6. On error: display error message and stop loading
   *
   * Security: Backend validates and sanitizes all inputs again.
   * Client validation is only for UX, not security.
   */
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) {
      setError("Please fill in all required fields correctly");
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // Send data to backend - it will validate everything again
      const counterparty = await createCounterparty(formData);
      
      // Save the returned ID to state for next step
      saveCheckoutState({ counterpartyId: counterparty.id });
      
      // Navigate to preview
      router.push("/checkout/preview");
    } catch (err: unknown) {
      // Display error message from API
      setError(
        err instanceof Error ? err.message : "Failed to create counterparty",
      );
      setLoading(false);
    }
  };

  // Check if form is valid for enabling/disabling submit button
  const isFormValid = validateForm();

  return (
    <div>
      <Stepper currentStep={2} />

      <div className="bg-white rounded-lg shadow-sm p-6">
        <h1 className="text-2xl font-bold mb-6">Customer Information</h1>

        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-4">
            <strong>Error:</strong> {error}
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div className="space-y-4 mb-6">
            <div>
              <label
                htmlFor="type"
                className="block text-sm font-medium text-gray-700 mb-1"
              >
                Type
              </label>
              <select
                id="type"
                name="type"
                value={formData.type}
                onChange={handleChange}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="person">Person</option>
                <option value="company">Company</option>
              </select>
            </div>

            <div>
              <label
                htmlFor="name"
                className="block text-sm font-medium text-gray-700 mb-1"
              >
                Name <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                id="name"
                name="name"
                value={formData.name}
                onChange={handleChange}
                required
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label
                htmlFor="street"
                className="block text-sm font-medium text-gray-700 mb-1"
              >
                Street <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                id="street"
                name="street"
                value={formData.street}
                onChange={handleChange}
                required
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label
                  htmlFor="postal_code"
                  className="block text-sm font-medium text-gray-700 mb-1"
                >
                  Postal Code <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  id="postal_code"
                  name="postal_code"
                  value={formData.postal_code}
                  onChange={handleChange}
                  required
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div>
                <label
                  htmlFor="city"
                  className="block text-sm font-medium text-gray-700 mb-1"
                >
                  City <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  id="city"
                  name="city"
                  value={formData.city}
                  onChange={handleChange}
                  required
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
            </div>

            <div>
              <label
                htmlFor="country"
                className="block text-sm font-medium text-gray-700 mb-1"
              >
                Country (2-letter code) <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                id="country"
                name="country"
                value={formData.country}
                onChange={handleChange}
                required
                maxLength={2}
                pattern="[A-Z]{2}"
                placeholder="e.g., DE, US, FR"
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label
                htmlFor="email"
                className="block text-sm font-medium text-gray-700 mb-1"
              >
                Email <span className="text-red-500">*</span>
              </label>
              <input
                type="email"
                id="email"
                name="email"
                value={formData.email}
                onChange={handleChange}
                required
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>

          <div className="flex justify-between">
            <button
              type="button"
              onClick={() => router.push("/checkout/offer")}
              className="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Back
            </button>
            <button
              type="submit"
              disabled={!isFormValid || loading}
              className={`px-6 py-2 rounded-lg ${
                isFormValid && !loading
                  ? "bg-blue-600 text-white hover:bg-blue-700"
                  : "bg-gray-300 text-gray-500 cursor-not-allowed"
              }`}
            >
              {loading ? "Submitting..." : "Continue"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
