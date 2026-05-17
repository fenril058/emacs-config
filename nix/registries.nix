inputs: [
  {
    name = "melpa";
    type = "melpa";
    path = inputs.melpa.outPath + "/recipes";
  }
  {
    name = "gnu-elpa";
    type = "elpa";
    path = inputs.gnu-elpa.outPath + "/elpa-packages";
    auto-sync-only = true;
    exclude = [
      "lv"
    ];
  }
  {
    name = "nongnu-elpa";
    type = "elpa";
    path = inputs.nongnu-elpa.outPath + "/elpa-packages";
  }
  {
    name = "emacsmirror";
    type = "gitmodules";
    path = inputs.epkgs.outPath + "/.gitmodules";
  }
]
