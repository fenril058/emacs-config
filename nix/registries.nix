inputs: [
  {
    name = "gnu";
    type = "elpa";
    path = inputs.elpa.outPath + "/elpa-packages";
    auto-sync-only = true;
    exclude = [
      "lv"
    ];
  }
  {
    name = "melpa";
    type = "melpa";
    path = inputs.melpa.outPath + "/recipes";
  }
  {
    type = "elpa";
    path = inputs.nongnu.outPath + "/elpa-packages";
  }
  {
    name = "gnu-devel";
    type = "archive";
    url = "https://elpa.gnu.org/devel/";
  }
  {
    name = "nongnu-devel";
    type = "archive";
    url = "https://elpa.nongnu.org/nongnu-devel/";
  }
  {
    name = "emacsmirror";
    type = "gitmodules";
    path = inputs.epkgs.outPath + "/.gitmodules";
  }
]
