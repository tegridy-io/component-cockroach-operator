local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.cockroach_operator;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('cockroach-operator', params.namespace);

{
  'cockroach-operator': app,
}
