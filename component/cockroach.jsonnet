// main template for cm-hetznercloud
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.cockroach_operator;

local cockroach = com.Kustomization(
  'https://github.com/cockroachdb/cockroach-operator//config/default',
  params.manifestVersion,
  {
    'cockroachdb/cockroach-operator': {
      newTag: params.images.operator.tag,
      newName: '%(registry)s/%(repository)s' % params.images.operator,
    },
  },
  params.kustomizeInput,
);

cockroach
