local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.cockroach_operator;


/**
  * \brief Helper to create CockroachDB objects.
  *
  * \arg The name of the database.
  * \return A CockroachDB object.
  */
local database(name, namespace, spec) = kube._Object('crdb.cockroachlabs.com/v1alpha1', 'CrdbCluster', name) {
  assert spec.nodes >= 3 : 'Parameter nodes should be >= 3.',
  assert spec.nodes % 2 != 0 : 'Parameter nodes should be a odd number.',
  metadata+: {
    labels+: {
      'app.kubernetes.io/component': 'database',
      'app.kubernetes.io/managed-by': 'commodore',
      'app.kubernetes.io/name': name,
    },
    namespace: namespace,
  },
  spec+: {
    nodes: spec.nodes,
    image: {
      name: '%(registry)s/%(repository)s:%(tag)s' % params.images.cockroach,
      pullPolicy: 'IfNotPresent',
    },
    tlsEnabled: std.get(spec, 'tlsEnabled', true),
    dataStore: {
      pvc: {
        spec: {
          accessModes: [ spec.storage.accessMode ],
          storageClassName: spec.storage.storageClass,
          resources: {
            requests: { storage: spec.storage.size },
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
                  values: [ name ],
                },
              ],
            },
            topologyKey: 'kubernetes.io/hostname',
          },
        ],
      },
    },
  },
};


/**
  * \brief Helper to create CockroachDB client.
  *
  * \arg The name of the database client.
  * \return A Deployment object.
  */
local client(name, namespace) = kube.Deployment(name + '-client') {
  metadata+: {
    labels+: {
      'app.kubernetes.io/component': 'database-client',
      'app.kubernetes.io/managed-by': 'commodore',
      'app.kubernetes.io/name': name + '-client',
    },
    namespace: namespace,
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
              COCKROACH_HOST: name + '-public',
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
              secretName: name + '-root',
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
};


{
  database: database,
  client: client,
}
