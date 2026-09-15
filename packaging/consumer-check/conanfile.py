import os

from conan import ConanFile


class ConsumerCheckConan(ConanFile):
    settings = "os", "arch", "compiler", "build_type"
    python_requires = "ios6-base/1.0@ios6/stable"

    def requirements(self):
        self.requires("tdlib/1.8.0@ios6/stable")

    def layout(self):
        self.folders.generators = os.path.join("build", "conan", str(self.settings.arch))

    def generate(self):
        self.python_requires["ios6-base"].module.DependencyEnv(self).generate()
