// Checkout state management with localStorage persistence

export interface CheckoutState {
  offerId: number | null;
  counterpartyId: number | null;
  contractId: string | null;
}

const STORAGE_KEY = "checkout_state";

export function saveCheckoutState(state: Partial<CheckoutState>): void {
  if (typeof window === "undefined") return;
  
  const currentState = getCheckoutState();
  const newState = { ...currentState, ...state };
  localStorage.setItem(STORAGE_KEY, JSON.stringify(newState));
}

export function getCheckoutState(): CheckoutState {
  if (typeof window === "undefined") {
    return { offerId: null, counterpartyId: null, contractId: null };
  }
  
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (!stored) {
      return { offerId: null, counterpartyId: null, contractId: null };
    }
    return JSON.parse(stored);
  } catch {
    return { offerId: null, counterpartyId: null, contractId: null };
  }
}

export function clearCheckoutState(): void {
  if (typeof window === "undefined") return;
  localStorage.removeItem(STORAGE_KEY);
}
