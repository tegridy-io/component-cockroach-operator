// main template for cockroach-operator
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.cockroach_operator;

local database(name) = [
  // namespace
  kube.Namespace(params.databases[name].namespace),
  // database
  kube._Object('crdb.cockroachlabs.com/v1alpha1', 'CrdbCluster', name + '-database') {
    assert params.databases[name].nodes >= 3 : 'Parameter nodes should be >= 3.',
    metadata+: {
      labels+: {
        'app.kubernetes.io/component': 'database',
        'app.kubernetes.io/managed-by': 'commodore',
        'app.kubernetes.io/name': name + '-database',
      },
      namespace: params.databases[name].namespace,
    },
    spec+: {
      nodes: params.databases[name].nodes,
      image: {
        name: '%(registry)s/%(repository)s:%(tag)s' % params.images.cockroach,
        pullPolicy: 'IfNotPresent',
      },
      tlsEnabled: true,
      dataStore: {
        pvc: {
          spec: {
            accessModes: [ params.databases[name].storage.accessMode ],
            storageClassName: params.databases[name].storage.storageClass,
            resources: {
              requests: { storage: params.databases[name].storage.size },
            },
            volumeMode: 'Filesystem',
          },
        },
      },
      affinity: {
        podAntiAffinity: {
          requiredDuringSchedulingIgnoredDuringExecution: [
            {
              labelSelector: {
                matchExpressions: [
                  {
                    key: 'app.kubernetes.io/name',
                    operator: 'In',
                    values: [ name + '-database' ],
                  },
                ],
              },
              topologyKey: 'kubernetes.io/hostname',
            },
          ],
        },
      },
    },
  },
  // client
  kube.Deployment(name + '-database-client') {
    metadata+: {
      labels+: {
        'app.kubernetes.io/component': 'client',
        'app.kubernetes.io/managed-by': 'commodore',
        'app.kubernetes.io/name': name + '-database-client',
      },
      namespace: params.databases[name].namespace,
    },
    spec+: {
      replicas: 1,
      template+: {
        spec+: {
          serviceAccountName: 'default',
          securityContext: {
            seccompProfile: { type: 'RuntimeDefault' },
          },
          containers_:: {
            default: kube.Container('client') {
              image: '%(registry)s/%(repository)s:%(tag)s' % params.images.cockroach,
              env_:: {
                COCKROACH_CERTS_DIR: '/cockroach/certs-dir',
                COCKROACH_HOST: name + '-database-public',
              },
              command: [ 'sleep', 'infinity' ],
              securityContext: {
                allowPrivilegeEscalation: false,
                capabilities: { drop: [ 'ALL' ] },
              },
              volumeMounts_:: {
                certs: { mountPath: '/cockroach/certs-dir' },
              },
            },
          },
          volumes_:: {
            certs: {
              secret: {
                secretName: name + '-database-root',
                items: [
                  { key: 'ca.crt', path: 'ca.crt' },
                  { key: 'tls.crt', path: 'client.root.crt' },
                  { key: 'tls.key', path: 'client.root.key' },
                ],
              },
            },
          },
        },
      },
    },
  },
];

// Define outputs below
{
  ['20_db_' + name]: database(name)
  for name in std.objectFields(params.databases)
}
