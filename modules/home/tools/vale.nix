{
  pkgs,
  inputs,
  ...
}:

let
  styles = pkgs.linkFarm "vale-styles" {
    proselint = "${inputs.vale-proselint}/proselint";
    write-good = "${inputs.vale-write-good}/write-good";
    alex = "${inputs.vale-alex}/alex";
    ai-tells = "${inputs.vale-ai-tells}/styles/ai-tells";
    "config/vocabularies/Jeff" = ./vale/Jeff;
  };
in
{
  home.packages = [ pkgs.vale ];

  # Vale uses ~/.vale.ini only without a project config; its global config merges into every project.
  home.file.".vale.ini".text = ''
    StylesPath = ${styles}
    MinAlertLevel = suggestion
    Vocab = Jeff

    [*]
    BasedOnStyles = Vale, write-good, proselint, alex, ai-tells
    alex.ProfanityUnlikely = NO
    # Technical prose and code samples use straight quotes.
    proselint.CurlyQuotes = NO
    # Terms enforces vocabulary case, which misfires at sentence starts; the vocab still feeds Spelling.
    Vale.Terms = NO
    write-good.E-Prime = NO
    # DoubleHyphen asks for an em dash; house rule is a plain dash.
    ai-tells.DoubleHyphen = NO
    # ParallelStaccato asks to merge short sentences; house style wants short sentences.
    ai-tells.ParallelStaccato = NO
    # ColonUsage flags commit trailers such as "Co-Authored-By: Claude Code".
    ai-tells.ColonUsage = NO
    # These rules suggest a passive rewrite; house style is active voice.
    ai-tells.BareReaches = NO
    ai-tells.FigurativeLands = NO
    ai-tells.FigurativeSweeps = NO
    ai-tells.FigurativeTravels = NO
    # "Shape" is common GraphQL vocabulary for an output structure.
    ai-tells.FigurativeShape = NO

    # Agent instructions and skills are not reader-facing prose.
    [{CLAUDE.md,AGENTS.md,SKILL.md,**/CLAUDE.md,**/AGENTS.md,**/SKILL.md,.claude/**/*.md}]
    BasedOnStyles = Vale, write-good, proselint, alex
  '';
}
