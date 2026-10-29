/// JavaScript run inside Google's pages. Kept together because these are what break when Google
/// changes its markup; `HaloSearch --selftest` exercises both against the live site.
public enum PageScripts {
    /// Reads the token Lens adds to its results page once the image has been analysed.
    public static let lensToken = "document.querySelector('[data-mstk]')?.getAttribute('data-mstk') ?? null"

    /// Asks a follow-up through AI Mode's own question box. Run with `callAsyncJavaScript`,
    /// passing `question`. Resolves to "sent", "no-box" or "not-sent".
    public static let askFollowUp = """
        const pause = ms => new Promise(done => setTimeout(done, ms));
        const shown = element => element.getClientRects().length > 0 && !element.disabled;

        let box;
        for (const deadline = Date.now() + 5000; !box && Date.now() < deadline; await pause(100)) {
          box = [...document.querySelectorAll("textarea")].reverse().find(shown);
        }
        if (!box) return "no-box";

        box.focus();
        box.select();
        if (!document.execCommand("insertText", false, question) || box.value !== question) {
          const setValue = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, "value").set;
          setValue.call(box, question);
          box.dispatchEvent(new Event("input", { bubbles: true }));
        }

        // The page clears the box once it accepts the question.
        const taken = () => !box.isConnected || box.value.trim() === "";
        for (let attempt = 0; attempt < 25 && !taken(); attempt++) {
          const options = { key: "Enter", code: "Enter", keyCode: 13, which: 13, bubbles: true, cancelable: true };
          box.dispatchEvent(new KeyboardEvent("keydown", options));
          box.dispatchEvent(new KeyboardEvent("keyup", options));
          await pause(200);
        }
        return taken() ? "sent" : "not-sent";
        """
}
