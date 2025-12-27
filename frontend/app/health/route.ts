import { NextResponse } from "next/server";

/**
 * Lightweight health check endpoint for container platforms.
 * Returns HTTP 200 for both GET and HEAD requests without touching external dependencies.
 */
export function GET() {
  return NextResponse.json(
    { status: "ok" },
    {
      status: 200,
      headers: {
        "Cache-Control": "no-store",
      },
    },
  );
}

export function HEAD() {
  return new Response(null, {
    status: 200,
    headers: {
      "Cache-Control": "no-store",
    },
  });
}
