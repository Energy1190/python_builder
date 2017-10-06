#!/usr/bin/env python3

import os
import time
import shutil
import docker
import traceback
from io import BytesIO
from docker import APIClient


def permission():
    os.system('chmod 777 /data/build.complate')
    os.system('chmod 777 /data/build.status')
    os.system('chmod 777 /data/build.log')


def get_env(env):
    x = open('/data/build.env', 'r')
    for i in x:
        if i.split(sep='=')[0] == env:
            return i.split(sep='=')[1].replace('\n', '').replace('\r', '')
    return False


def complate():
    x = open('/data/build.complate', 'w')
    x.write('1')
    x.close()
    permission()


def status(num):
    x = open('/data/build.status', 'w')
    x.write(num)
    x.close()


def clen_dir(dir='/data/'):
    for i in os.listdir(dir):
        if os.path.isfile(dir + i):
            os.remove(dir + i)
        elif os.path.isdir(dir + i):
            clen_dir(dir=dir + i + '/')
            os.rmdir(dir + i)
        else:
            print('Somfing wrong in {}'.format(dir + i))


def fail(fail_log):
    clen_dir()
    if type(fail_log) == list: fail_log = '\n'.join(fail_log)
    x = open('/data/build.log', 'w')
    x.write(fail_log)
    x.close()
    status('1')
    complate()


def build_and_push(user, paswd, name, tag, version='1.23'):
    def low_level_build(IMAGE, tag, version):
        x = APIClient(base_url='unix://tmp/run/docker.sock', version=version)
        response = [line for line in x.build(path='/data', rm=True, tag='{}:{}'.format(IMAGE, tag))]
        return response

    log = open('/build.log', 'w')
    IMAGE = user + '/' + name
    dc = docker.DockerClient(base_url='unix://tmp/run/docker.sock', version=version)
    try:
        #        x = dc.images.build(path='/data', tag='{}:{}'.format(IMAGE, tag))
        x = list(map(str, low_level_build(IMAGE, tag, version)))
        list(map(log.write, x))
    except docker.errors.BuildError as e:
        log.write(str(traceback.format_exc()))
        return False

    for i in dc.images.push(IMAGE, stream=True, tag=tag, auth_config={'username': user, 'password': paswd}):
        log.write(str(i))
    log.close()
    return True


def main():
    if not os.path.exists('/data/build.wait'): return False
    if not os.path.exists('/data/build.env'): return False

    print('')
    print('Start build image.')

    USERNAME = get_env('USERNAME')
    PASSWORD = get_env('PASSWORD')
    PATH = get_env('PATH')
    TAG = get_env('TAG')

    if not USERNAME: return fail('It is impossible to get a variable - USERNAME.')
    if not PASSWORD: return fail('It is impossible to get a variable - PASSWORD.')
    if not PATH: return fail('It is impossible to get a variable - PATH.')
    if not TAG: return fail('It is impossible to get a variable - TAG.')

    if not os.path.exists('/tmp/run/docker.sock'): return fail('no required file - docker.sock')
    if not os.path.exists('/data/Dockerfile'): return fail('no required file - Dockerfile')

    print('')
    print('Name: {}'.format(USERNAME + '/' + PATH))
    print('Tag: {}'.format(TAG))

    x = build_and_push(USERNAME, PASSWORD, PATH, TAG)
    clen_dir()
    shutil.move('/build.log', '/data/build.log')

    if not x:
        status('1')
    else:
        status('0')

    complate()


if __name__ == '__main__':
    print('Python-bulder: Start work')
    while True:
        time.sleep(5)
        main()
