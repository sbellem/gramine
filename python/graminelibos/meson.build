conf = configuration_data()
conf.set('VERSION', meson.project_version())
conf.set('PKGLIBDIR', join_paths(get_option('prefix'), pkglibdir))
conf.set('LIBDIR', join_paths(get_option('prefix'), get_option('libdir')))
conf.set('SGX_ENABLED', sgx ? '1' : '0')

init_py = configure_file(
    input: '__init__.py',
    output: '__init__.py',
    configuration: conf,
)

install_data([
    init_py,
    'gen_jinja_env.py',
    'manifest.py',
], install_dir: python3_pkgdir)

if sgx
    install_data([
        '_aesm_pb2.py',
        'sgx_get_token.py',
        'sgx_sign.py',
        'sigstruct.py',
    ], install_dir: python3_pkgdir)
endif
