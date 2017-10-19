#!/usr/bin/env python3

import os
import ast
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


def log_generate(data, file_obj):
    print('DEBUG:', data)
    flag = 0
    def analaze(data, file_obj):
        nonlocal flag
        assert type(data) == dict
        if len(list(data)) == 1:
            if 'stream' in list(data):
                print(data['stream'].strip())
                file_obj.write(data['stream'].strip() + '\n')
            if 'message' in list(data):
                print('MESSAGE:', data['message'].strip())
                file_obj.write('MESSAGE:', data['message'].strip() + '\n')
        elif len(list(data)) == 2:
            if 'message' in list(data):
                print('MESSAGE:', data['message'].strip())
                file_obj.write('MESSAGE:', data['message'].strip() + '\n')
            if 'code' in list(data):
                print('CODE:', data['code'])
                file_obj.write('CODE:', data['code'] + '\n')
            if 'error' in list(data):
                flag = 1
                print('ERROR:', data['error'].strip())
                file_obj.write('ERROR:', data['error'].strip() + '\n')
            if 'errorDetail' in list(data):
                print('ERROR DETAIL:')
                file_obj.write('ERROR DETAIL:' + '\n')
                analaze(data['errorDetail'], file_obj)
        else:
            print('UNKNOWN:', data)
    try:
        x = data.replace('\r\n', '').replace('\\n', '')
        y = ast.literal_eval(str(ast.literal_eval(x), 'utf-8'))
        analaze(y, file_obj)
    except:
        print(str(traceback.format_exc()))
        file_obj.write(data + '\n')
        file_obj.write(str(traceback.format_exc()))
    return flag

def build_and_push(user, paswd, name, tag, version='1.23'):
    status = True
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
        if any([log_generate(i, log) for i in x]): status = False
    except docker.errors.BuildError as e:
        log.write(str(traceback.format_exc()))
        return status

    for i in dc.images.push(IMAGE, stream=True, tag=tag, auth_config={'username': user, 'password': paswd}):
        log_generate(i, log)
    log.close()
    return status


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
    print('Done.')


if __name__ == '__main__':
    print('Python-bulder: Start work')
    while True:
        time.sleep(5)
        main()
