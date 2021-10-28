
import io
import os
import platform
import subprocess
import sys

import toml

from . import ninja_syntax, _CONFIG_PKGLIBDIR


def get_list(data, *keys):
    for key in keys:
        if key not in data:
            return []
        data = data[key]
    return data


class TestConfig:
    def __init__(self, path):
        self.config_path = path

        data = toml.load(path)

        self.manifests = get_list(data, 'manifests')
        arch = platform.processor()
        self.manifests += get_list(data, 'arch', arch, 'manifests')

        self.sgx_manifests = get_list(data, 'sgx', 'manifests')

        binary_dir = data.get('binary_dir')
        if binary_dir:
            self.binary_dir = binary_dir.replace('@GRAMINE_PKGLIBDIR@', _CONFIG_PKGLIBDIR)
        else:
            self.binary_dir = '.'

        self.arch_libdir = '/lib/x86_64-linux-gnu/'  # TODO

        toplevel = subprocess.check_output(['git', 'rev-parse', '--show-toplevel']).decode().strip()
        self.key = os.path.join(toplevel, 'Pal/src/host/Linux-SGX/signer/enclave-key.pem')

        if data.get('all_executables'):
            for name in os.listdir(binary_dir):
                if os.access(os.path.join(binary_dir, name), os.X_OK):
                    self.manifests.append(name)

        self.all_manifests = self.manifests + self.sgx_manifests

    def gen_build_file(self, path):
        output = io.StringIO()
        ninja = ninja_syntax.Writer(output)

        self._gen_header(ninja)
        self._gen_rules(ninja, path)
        self._gen_targets(ninja)

        with open(path, 'w') as f:
            f.write(output.getvalue())

    def _gen_header(self, ninja):
        ninja.comment('Auto-generated, do not edit!')
        ninja.newline()

    def _gen_rules(self, ninja, ninja_path):
        ninja.variable('BINARY_DIR', self.binary_dir)
        ninja.variable('ARCH_LIBDIR', self.arch_libdir)
        ninja.variable('KEY', self.key)
        ninja.newline()

        ninja.rule(
            name='manifest',
            command=('gramine-manifest '
                     '-Darch_libdir=$ARCH_LIBDIR '
                     '-Dentrypoint=$ENTRYPOINT '
                     '-Dbinary_dir=$BINARY_DIR '
                     '$in $out'),
            description='manifest: $out'
        )
        ninja.newline()

        ninja.rule(
            name='sgx-sign',
            command=('gramine-sgx-sign --quiet --manifest $in --key $KEY --depfile $out.d '
                     '--output $out'),
            depfile='$out.d',
            description='SGX sign: $out',
        )
        ninja.newline()

        ninja.rule(
            name='sgx-get-token',
            command='gramine-sgx-get-token --quiet --sig $in --output $out',
            description='SGX token: $out',
        )
        ninja.newline()

        ninja.rule(
            name='regenerate',
            command='gramine-test regenerate',
            description='Regenerating build file',
            generator=True,
        )

        ninja.build(
            outputs=[ninja_path],
            rule='regenerate',
            inputs=[self.config_path],
        )

        ninja.newline()

    def _gen_targets(self, ninja):
        ninja.build(
            outputs=['direct'],
            rule='phony',
            inputs=([f'{name}.manifest' for name in self.manifests]),
        )
        ninja.default('direct')
        ninja.newline()

        ninja.build(
            outputs=['sgx'],
            rule='phony',
            inputs=([f'{name}.manifest' for name in self.all_manifests] +
                    [f'{name}.manifest.sgx' for name in self.all_manifests] +
                    [f'{name}.sig' for name in self.all_manifests] +
                    [f'{name}.token' for name in self.all_manifests]),
        )
        ninja.newline()

        for name in self.all_manifests:
            template = f'{name}.manifest.template'
            if not os.path.exists(template):
                template = 'manifest.template'

            ninja.build(
                outputs=[f'{name}.manifest'],
                rule='manifest',
                inputs=[template],
                variables={'ENTRYPOINT': name},
            )

            ninja.build(
                outputs=[f'{name}.manifest.sgx'],
                implicit_outputs=[f'{name}.sig'],
                rule='sgx-sign',
                inputs=[f'{name}.manifest'],
                implicit=([self.key]),
            )

            ninja.build(
                outputs=[f'{name}.token'],
                rule='sgx-get-token',
                inputs=[f'{name}.sig'],
            )

            ninja.build(
                outputs=[f'direct-{name}'],
                rule='phony',
                inputs=[f'{name}.manifest'],
            )

            ninja.build(
                outputs=[f'sgx-{name}'],
                rule='phony',
                inputs=[f'{name}.manifest', f'{name}.manifest.sgx', f'{name}.sig', f'{name}.token'],
            )

            ninja.newline()


def gen_build_file():
    config = TestConfig('tests.toml')
    config.gen_build_file('build.ninja')


def exec_pytest(sgx, args):
    env = os.environ.copy()
    env['SGX'] = '1' if sgx else ''

    argv = [os.path.basename(sys.executable), '-m', 'pytest'] + list(args)
    print(' '.join(argv))
    os.execve(sys.executable, argv, env)


def run_ninja(args):
    argv = ['ninja'] + list(args)
    print(' '.join(argv))
    subprocess.check_call(argv)


def exec_gramine(sgx, name, args):
    prog = 'gramine-sgx' if sgx else 'gramine-direct'
    argv = [prog, name] + list(args)
    print(' '.join(argv))
    os.execvp(prog, argv)
