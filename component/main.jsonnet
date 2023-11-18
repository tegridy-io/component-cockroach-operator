// main template for cockroach-operator
local crdb = import 'lib/cockroach-operator.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.cockroach_operator;

local database(name) = [
  // namespace
  kube.Namespace(params.databases[name].namespace),
  // database
  crdb.database(name + '-database', params.databases[name].namespace, params.databases[name]),
  // client
  crdb.client(name + '-database', params.databases[name].namespace),
];

// Define outputs below
{
  ['20_db_' + name]: database(name)
  for name in std.objectFields(params.databases)
}
