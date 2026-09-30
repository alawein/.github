import { describe, expect, it } from "vitest";
import { slugify } from "./slugify";

describe("slugify", () => {
  it("lowercases and joins words with hyphens", () => {
    expect(slugify("Hello, World")).toBe("hello-world");
  });

  it("trims leading and trailing separators", () => {
    expect(slugify("  --Notes--  ")).toBe("notes");
  });
});
