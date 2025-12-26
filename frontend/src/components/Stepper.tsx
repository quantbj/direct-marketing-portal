"use client";

interface StepperProps {
  currentStep: number;
}

const steps = [
  { number: 1, label: "Offer" },
  { number: 2, label: "Customer" },
  { number: 3, label: "Preview" },
  { number: 4, label: "Sign" },
];

export default function Stepper({ currentStep }: StepperProps) {
  return (
    <div className="w-full mb-8">
      <div className="flex items-center justify-between max-w-2xl mx-auto">
        {steps.map((step, index) => (
          <div key={step.number} className="flex items-center flex-1">
            <div className="flex flex-col items-center flex-1">
              <div
                className={`w-10 h-10 rounded-full flex items-center justify-center font-semibold ${
                  step.number === currentStep
                    ? "bg-blue-600 text-white"
                    : step.number < currentStep
                      ? "bg-green-600 text-white"
                      : "bg-gray-300 text-gray-600"
                }`}
              >
                {step.number}
              </div>
              <div className="mt-2 text-sm font-medium text-gray-700">
                {step.label}
              </div>
            </div>
            {index < steps.length - 1 && (
              <div
                className={`h-1 flex-1 mx-2 ${
                  step.number < currentStep ? "bg-green-600" : "bg-gray-300"
                }`}
              />
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
