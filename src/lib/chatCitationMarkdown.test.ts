import { describe, expect, it } from "vitest";
import { replaceCitationLinksWithIndexes } from "@/lib/chatCitationMarkdown";

describe("replaceCitationLinksWithIndexes", () => {
  it("replaces inline citation links with citation indexes", () => {
    const markdown =
      "先别用力揉。([abm.memberclicks.net](https://abm.memberclicks.net/protocols)) 如果发热要联系医生。[www.cdc.gov](https://www.cdc.gov/breastfeeding/mastitis)";

    expect(
      replaceCitationLinksWithIndexes(markdown, [
        { index: 1, title: "ABM Protocol", url: "https://abm.memberclicks.net/protocols" },
        { index: 2, title: "CDC Breastfeeding", url: "https://www.cdc.gov/breastfeeding/mastitis" },
      ]),
    ).toBe("先别用力揉。[1] 如果发热要联系医生。[2]");
  });

  it("falls back to the first citation from the same host", () => {
    const markdown = "参考 CDC。([www.cdc.gov](https://www.cdc.gov/another-page))";

    expect(
      replaceCitationLinksWithIndexes(markdown, [
        { index: 1, title: "CDC Breastfeeding", url: "https://www.cdc.gov/breastfeeding/mastitis" },
      ]),
    ).toBe("参考 CDC。[1]");
  });

  it("leaves non-citation links unchanged", () => {
    const markdown = "打开 [Momcozy](https://example.com/product)。";

    expect(
      replaceCitationLinksWithIndexes(markdown, [
        { index: 1, title: "CDC Breastfeeding", url: "https://www.cdc.gov/breastfeeding/mastitis" },
      ]),
    ).toBe(markdown);
  });
});
