import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import Stepper from "../components/Stepper";

describe("Stepper Component", () => {
  it("should render all steps", () => {
    render(<Stepper currentStep={1} />);
    expect(screen.getByText("Offer")).toBeInTheDocument();
    expect(screen.getByText("Customer")).toBeInTheDocument();
    expect(screen.getByText("Preview")).toBeInTheDocument();
    expect(screen.getByText("Sign")).toBeInTheDocument();
  });

  it("should highlight current step", () => {
    render(<Stepper currentStep={2} />);
    const customerStep = screen.getByText("2");
    expect(customerStep).toBeInTheDocument();
  });

  it("should show all four steps", () => {
    render(<Stepper currentStep={3} />);
    expect(screen.getByText("1")).toBeInTheDocument();
    expect(screen.getByText("2")).toBeInTheDocument();
    expect(screen.getByText("3")).toBeInTheDocument();
    expect(screen.getByText("4")).toBeInTheDocument();
  });
});
