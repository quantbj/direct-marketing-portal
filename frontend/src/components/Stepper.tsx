/**
 * Stepper Component - Visual Progress Indicator
 *
 * Displays the user's progress through the 4-step checkout flow.
 * Shows completed, current, and upcoming steps with visual indicators.
 *
 * Step flow:
 * 1. Offer - Select a marketing contract offer
 * 2. Customer - Enter customer information
 * 3. Preview - Review contract and PDF
 * 4. Sign - Complete e-signature
 */

"use client";

interface StepperProps {
  /** Current step number (1-4) */
  currentStep: number;
}

/**
 * Configuration for each step in the checkout flow.
 * This is a fixed array defining the progression.
 */
const steps = [
  { number: 1, label: "Offer" },
  { number: 2, label: "Customer" },
  { number: 3, label: "Preview" },
  { number: 4, label: "Sign" },
] as const;

/**
 * Renders a horizontal stepper showing checkout progress.
 *
 * Visual indicators:
 * - Completed steps: Green circle with white number
 * - Current step: Blue circle with white number
 * - Upcoming steps: Gray circle with gray number
 * - Connectors between steps: Green (completed) or gray (not yet)
 *
 * @param currentStep - The active step number (1-4)
 *
 * @example
 * ```tsx
 * // On the customer data page (step 2)
 * <Stepper currentStep={2} />
 * ```
 *
 * Accessibility notes:
 * - Uses semantic HTML with descriptive labels
 * - Color is not the only indicator (numbers also present)
 * - Could be enhanced with ARIA labels for screen readers
 */
export default function Stepper({ currentStep }: StepperProps) {
  return (
    <div className="w-full mb-8">
      <div className="flex items-center justify-between max-w-2xl mx-auto">
        {steps.map((step, index) => (
          <div key={step.number} className="flex items-center flex-1">
            {/* Step circle and label */}
            <div className="flex flex-col items-center flex-1">
              {/* Circle indicator with step number */}
              <div
                className={`w-10 h-10 rounded-full flex items-center justify-center font-semibold ${
                  step.number === currentStep
                    ? "bg-blue-600 text-white" // Current step: Blue
                    : step.number < currentStep
                      ? "bg-green-600 text-white" // Completed step: Green
                      : "bg-gray-300 text-gray-600" // Upcoming step: Gray
                }`}
              >
                {step.number}
              </div>
              {/* Step label below circle */}
              <div className="mt-2 text-sm font-medium text-gray-700">
                {step.label}
              </div>
            </div>
            
            {/* Connector line between steps (not shown after last step) */}
            {index < steps.length - 1 && (
              <div
                className={`h-1 flex-1 mx-2 ${
                  step.number < currentStep 
                    ? "bg-green-600" // Completed: Green line
                    : "bg-gray-300" // Not completed: Gray line
                }`}
              />
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
