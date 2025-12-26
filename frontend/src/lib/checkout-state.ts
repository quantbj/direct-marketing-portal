/**
 * Checkout State Management with localStorage Persistence
 *
 * This module manages the checkout flow state across page refreshes and navigation.
 * State is stored in the browser's localStorage to survive page reloads.
 *
 * The checkout flow progresses through 4 steps:
 * 1. Offer selection (stores offerId)
 * 2. Customer data entry (stores counterpartyId)
 * 3. Contract preview (stores contractId)
 * 4. Signing
 *
 * Security considerations:
 * - No sensitive data (passwords, payment info) is stored
 * - IDs are opaque references that require backend validation
 * - State is client-side only and can be tampered with (backend validates all operations)
 * - SSR-safe: All localStorage access is guarded by window checks
 */

/**
 * Shape of the checkout state stored in localStorage.
 * All fields are nullable to represent the initial empty state.
 */
export interface CheckoutState {
  /** ID of the selected offer, null if not yet selected */
  offerId: number | null;
  /** ID of the created counterparty, null if not yet created */
  counterpartyId: number | null;
  /** UUID of the contract, null if not yet created */
  contractId: string | null;
}

/**
 * localStorage key for persisting checkout state.
 * Namespaced to avoid conflicts with other application data.
 */
const STORAGE_KEY = "checkout_state";

/**
 * Default empty state returned when no state is stored or on SSR.
 */
const DEFAULT_STATE: CheckoutState = {
  offerId: null,
  counterpartyId: null,
  contractId: null,
};

/**
 * Saves partial checkout state to localStorage, merging with existing state.
 *
 * This function uses a merge strategy: it reads the current state,
 * applies the updates, and writes back the complete state. This allows
 * updating individual fields without affecting others.
 *
 * @param state - Partial state to save (only fields to update)
 *
 * @example
 * ```ts
 * // After offer selection
 * saveCheckoutState({ offerId: 123 });
 *
 * // After customer creation (preserves offerId)
 * saveCheckoutState({ counterpartyId: 456 });
 *
 * // Now state is: { offerId: 123, counterpartyId: 456, contractId: null }
 * ```
 *
 * Security notes:
 * - SSR-safe: Returns early if window is undefined (server-side rendering)
 * - No validation of values (backend validates all IDs)
 * - localStorage is origin-scoped (same-origin policy applies)
 */
export function saveCheckoutState(state: Partial<CheckoutState>): void {
  // Guard against SSR - localStorage only available in browser
  if (typeof window === "undefined") return;
  
  const currentState = getCheckoutState();
  const newState = { ...currentState, ...state };
  
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(newState));
  } catch (error) {
    // localStorage may be disabled or full (quota exceeded)
    // Log error but don't throw - state will be lost on refresh but flow continues
    console.error("Failed to save checkout state:", error);
  }
}

/**
 * Retrieves the current checkout state from localStorage.
 *
 * @returns Current checkout state, or default empty state if:
 *   - Running on server (SSR)
 *   - No state is stored
 *   - Stored state is corrupted (invalid JSON)
 *
 * @example
 * ```ts
 * const state = getCheckoutState();
 * if (state.offerId) {
 *   console.log("User has selected offer:", state.offerId);
 * } else {
 *   // Redirect to offer selection
 * }
 * ```
 *
 * Security notes:
 * - Returns safe defaults if JSON parsing fails (corrupt data)
 * - No sensitive data is stored, only reference IDs
 * - State can be manipulated by user but backend validates everything
 */
export function getCheckoutState(): CheckoutState {
  // Guard against SSR - localStorage only available in browser
  if (typeof window === "undefined") {
    return DEFAULT_STATE;
  }
  
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (!stored) {
      return DEFAULT_STATE;
    }
    
    // Parse stored JSON and validate it has the expected shape
    const parsed = JSON.parse(stored);
    
    // Basic validation: ensure we got an object
    if (typeof parsed !== "object" || parsed === null) {
      return DEFAULT_STATE;
    }
    
    // Return parsed state with defaults for any missing fields
    return {
      offerId: parsed.offerId ?? null,
      counterpartyId: parsed.counterpartyId ?? null,
      contractId: parsed.contractId ?? null,
    };
  } catch (error) {
    // JSON parse error or localStorage access error
    // Return default state to allow flow to continue
    console.error("Failed to load checkout state:", error);
    return DEFAULT_STATE;
  }
}

/**
 * Clears all checkout state from localStorage.
 *
 * This is called when the user clicks "Start Over" or completes the flow.
 * After clearing, the user can begin a new checkout flow from step 1.
 *
 * @example
 * ```ts
 * function handleStartOver() {
 *   clearCheckoutState();
 *   router.push("/checkout/offer");
 * }
 * ```
 *
 * Security notes:
 * - SSR-safe: Returns early if window is undefined
 * - Errors are caught and logged (won't throw if localStorage unavailable)
 */
export function clearCheckoutState(): void {
  // Guard against SSR - localStorage only available in browser
  if (typeof window === "undefined") return;
  
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch (error) {
    // localStorage may be disabled
    console.error("Failed to clear checkout state:", error);
  }
}
