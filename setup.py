# from setuptools import setup, find_packages
import setuptools

with open("README.md", "r") as fh:
    long_description = fh.read()

with open('requirements.txt') as f:
    required = f.read().splitlines()


setuptools.setup(
    name='arldm',
    version='0.1',
    author="Pan, Xichen and Qin, Pengda and Li, Yuhong and Xue, Hui and Chen, Wenhu",
    packages=setuptools.find_packages(),
    url="https://github.com/candiceT233/ARLDM",
    py_modules=['arldm.datasets'],  # Add pororo.py as a module
    # install_requires=[
    #     # List your dependencies here
    # ],
    entry_points={
        'console_scripts': [
            'arldm = arldm.main:main',
        ],
    },
)