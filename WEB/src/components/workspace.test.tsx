import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { DataTable, EmptyState, PageHeader, StatusMessages } from "./workspace";

describe("workspace primitives", () => {
  it("renders a page title, context, and primary action", () => {
    render(<PageHeader title="Accounts" context="256 active accounts" action={<button>Create account</button>} />);

    expect(screen.getByRole("heading", { name: "Accounts" })).toBeVisible();
    expect(screen.getByText("256 active accounts")).toBeVisible();
    expect(screen.getByRole("button", { name: "Create account" })).toBeVisible();
  });

  it("renders a labelled table and an actionable empty state", () => {
    render(
      <>
        <DataTable caption="Accounts" headers={["Code", "Balance"]} rows={[]} numericColumns={[1]} />
        <EmptyState title="No accounts found" detail="Clear the search or create a new account." />
      </>,
    );

    expect(screen.getByRole("table", { name: "Accounts" })).toBeVisible();
    expect(screen.getByText("No accounts found")).toBeVisible();
  });

  it("announces success and error feedback", () => {
    render(<StatusMessages error="403: Forbidden" message="Account created." />);

    expect(screen.getByRole("alert")).toHaveTextContent("403: Forbidden");
    expect(screen.getByRole("status")).toHaveTextContent("Account created.");
  });
});
