{ lib, self, ... }:
let
  inherit (builtins) head tail length isList isAttrs attrValues filter;

  elib = self.lib;

  /* Recursively visit the attrset */
  visitorVisitAttrs = visitor: lib.mapAttrs (_: v: visit visitor v);
  /* recursively visits the list */
  visitorVisitList = visitor: map (v: visit visitor v);
  visitorVisitOther = visitor: v: v;

  /* trivial visitor that simply recurses */
  defaultVisitor = {
    visitAttrs = visitorVisitAttrs defaultVisitor;
    visitList = visitorVisitList defaultVisitor;
    visitOther = visitorVisitOther defaultVisitor;
  };

  visit =
    visitor @
      {
        visitAttrs ? (value: lib.mapAttrs (_: v: visit visitor v) value),
        visitList ? (value: map (v: visit visitor v) value),
        visitOther ? (value: value),
      }:
    value:
    if isAttrs value then visitAttrs value
    else if isList value then visitList value
    else visitOther value;

  findFirstMatch = matcher: value:
    let
      visitAttrs =
        v: if matcher v then v
           else visitListInner (attrValues v);

      visitList = v: if matcher v then v else visitListInner v;
      visitListInner =
        lib.foldl (lhs: rhs: if lhs != null
                                then lhs
                                else visit visitor rhs) null;

      visitOther = v: if matcher v then v else null;

      visitor = { inherit visitAttrs visitList visitOther; };
    in
      visit visitor value;

  /* Find all values matching a function and collect them into a list */
  findAllMatches = matcher: value:
    let
      visitAttrs = v: if matcher v then [v] else visitListInner (attrValues v);
      visitList = v: if matcher v then [v] else visitListInner v;
      visitListInner = val:
        lib.pipe val
          [ (map (visit visitor))
            (filter (v: v != null))
            (lib.foldl (lhs: rhs: lhs ++ rhs) [])
          ];
      visitOther = v: if matcher v then [v] else null;
      visitor = { inherit visitAttrs visitList visitOther; };
    in
      visit visitor value;

  mapAllMatching = matcher: mapper: value:
    let
      visitAttrs = v: if matcher v then mapper v else
        lib.mapAttrsWith (_: visit visitor) v;
      visitList = if matcher v then mapper v
                  else map (visit visitor) v;
      visitOther = if matcher v then v else mapper v;
      visitor = { inherit visitAttrs visitList visitOther; };
    in
      visit visitor value;

  /* Merge two attrsets with the given methods */
  mergeAttrsWith =
    methods @
      {
        mergeLists ? (lhs: rhs: lhs ++ rhs) /* Merge two lists */
      , mergeMismatched ? (lhs: rhs: rhs)   /* Merge two attributes of mismatched or non collective types */
      , mergeAttrs                          /* Merge two attribute sets */
        ? (lhs: rhs:
          lib.zipAttrsWith (_: values:
            if (length values) == 1 then (head values)
            else mergeAttrsWith methods (head values) (head (tail values)))
            [ lhs rhs ])
      }:
    lhs: rhs:
    if (isList lhs) && (isList rhs) then mergeLists lhs rhs
    else if (isAttrs lhs) && (isAttrs rhs) then mergeAttrs lhs rhs
    else mergeMismatched lhs rhs;
in
{
  inherit
    mergeAttrsWith

    findFirstMatch
    findAllMatches
    mapAllMatching

    visitorVisitAttrs
    visitorVisitList
    visitorVisitOther
    defaultVisitor
    visit;
}
