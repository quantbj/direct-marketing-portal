import { describe, it, expect, beforeEach } from "vitest";
import {
  saveCheckoutState,
  getCheckoutState,
  clearCheckoutState,
} from "../lib/checkout-state";

describe("Checkout State Management", () => {
  beforeEach(() => {
    // Clear localStorage before each test
    localStorage.clear();
  });

  it("should save and retrieve checkout state", () => {
    saveCheckoutState({ offerId: 1 });
    const state = getCheckoutState();
    expect(state.offerId).toBe(1);
    expect(state.counterpartyId).toBeNull();
    expect(state.contractId).toBeNull();
  });

  it("should merge state updates", () => {
    saveCheckoutState({ offerId: 1 });
    saveCheckoutState({ counterpartyId: 2 });
    const state = getCheckoutState();
    expect(state.offerId).toBe(1);
    expect(state.counterpartyId).toBe(2);
    expect(state.contractId).toBeNull();
  });

  it("should clear checkout state", () => {
    saveCheckoutState({ offerId: 1, counterpartyId: 2, contractId: "abc" });
    clearCheckoutState();
    const state = getCheckoutState();
    expect(state.offerId).toBeNull();
    expect(state.counterpartyId).toBeNull();
    expect(state.contractId).toBeNull();
  });

  it("should return default state when nothing saved", () => {
    const state = getCheckoutState();
    expect(state).toEqual({
      offerId: null,
      counterpartyId: null,
      contractId: null,
    });
  });

  it("should handle invalid JSON in localStorage", () => {
    localStorage.setItem("checkout_state", "invalid json");
    const state = getCheckoutState();
    expect(state).toEqual({
      offerId: null,
      counterpartyId: null,
      contractId: null,
    });
  });
});
