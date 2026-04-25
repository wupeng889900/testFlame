package com.aliyun.sample;

import com.aliyun.tea.*;

public class Sample {

    /**
     * <b>description</b> :
     * <p>使用凭据初始化账号Client</p>
     * @return Client
     * 
     * @throws Exception
     */
    public static com.aliyun.aiccs20191015.Client createClient() throws Exception {
        // 工程代码建议使用更安全的无AK方式，凭据配置方式请参见：https://help.aliyun.com/document_detail/378657.html。
        com.aliyun.credentials.Client credential = new com.aliyun.credentials.Client();
        com.aliyun.teaopenapi.models.Config config = new com.aliyun.teaopenapi.models.Config()
                .setCredential(credential);
        // Endpoint 请参考 https://api.aliyun.com/product/aiccs
        config.endpoint = "aiccs.aliyuncs.com";
        return new com.aliyun.aiccs20191015.Client(config);
    }

    public static void main(String[] args_) throws Exception {
        
        com.aliyun.aiccs20191015.Client client = Sample.createClient();
        com.aliyun.aiccs20191015.models.LlmSmartCallRequest llmSmartCallRequest = new com.aliyun.aiccs20191015.models.LlmSmartCallRequest()
                .setCalledNumber("18811444756");
        com.aliyun.teautil.models.RuntimeOptions runtime = new com.aliyun.teautil.models.RuntimeOptions();
        try {
            com.aliyun.aiccs20191015.models.LlmSmartCallResponse resp = client.llmSmartCallWithOptions(llmSmartCallRequest, runtime);
            System.out.println(new com.google.gson.Gson().toJson(resp));
        } catch (TeaException error) {
            // 此处仅做打印展示，请谨慎对待异常处理，在工程项目中切勿直接忽略异常。
            // 错误 message
            System.out.println(error.getMessage());
            // 诊断地址
            System.out.println(error.getData().get("Recommend"));
        } catch (Exception _error) {
            TeaException error = new TeaException(_error.getMessage(), _error);
            // 此处仅做打印展示，请谨慎对待异常处理，在工程项目中切勿直接忽略异常。
            // 错误 message
            System.out.println(error.getMessage());
            // 诊断地址
            System.out.println(error.getData().get("Recommend"));
        }        
    }
}
