# -*- coding: utf-8 -*-
# This file is auto-generated, don't edit it. Thanks.
import os
import sys
import json

from typing import List

from alibabacloud_aiccs20191015.client import Client as aiccs20191015Client
from alibabacloud_credentials.client import Client as CredentialClient
from alibabacloud_tea_openapi import models as open_api_models
from alibabacloud_aiccs20191015 import models as aiccs_20191015_models
from alibabacloud_tea_util import models as util_models
from alibabacloud_tea_util.client import Client as UtilClient


class Sample:
    def __init__(self):
        pass

    @staticmethod
    def create_client() -> aiccs20191015Client:
        """
        使用凭据初始化账号Client
        @return: Client
        @throws Exception
        """
        # 工程代码建议使用更安全的无AK方式，凭据配置方式请参见：https://help.aliyun.com/document_detail/378659.html。
        credential = CredentialClient()
        config = open_api_models.Config(
            credential=credential
        )
        # Endpoint 请参考 https://api.aliyun.com/product/aiccs
        config.endpoint = f'aiccs.aliyuncs.com'
        return aiccs20191015Client(config)

    @staticmethod
    def main(
        args: List[str],
    ) -> None:
        client = Sample.create_client()
        llm_smart_call_request = aiccs_20191015_models.LlmSmartCallRequest(
            caller_number='02131445003',
            called_number='18811444756',
            application_code='D363269572'
        )
        runtime = util_models.RuntimeOptions()
        try:
            resp = client.llm_smart_call_with_options(llm_smart_call_request, runtime)
            print(json.dumps(resp, default=str, indent=2))
        except Exception as error:
            # 此处仅做打印展示，请谨慎对待异常处理，在工程项目中切勿直接忽略异常。
            # 错误 message
            print(error.message)
            # 诊断地址
            print(error.data.get("Recommend"))

    @staticmethod
    async def main_async(
        args: List[str],
    ) -> None:
        client = Sample.create_client()
        llm_smart_call_request = aiccs_20191015_models.LlmSmartCallRequest(
            caller_number='02131445003',
            called_number='18811444756',
            application_code='D363269572'
        )
        runtime = util_models.RuntimeOptions()
        try:
            resp = await client.llm_smart_call_with_options_async(llm_smart_call_request, runtime)
            print(json.dumps(resp, default=str, indent=2))
        except Exception as error:
            # 此处仅做打印展示，请谨慎对待异常处理，在工程项目中切勿直接忽略异常。
            # 错误 message
            print(error.message)
            # 诊断地址
            print(error.data.get("Recommend"))


if __name__ == '__main__':
    Sample.main(sys.argv[1:])
