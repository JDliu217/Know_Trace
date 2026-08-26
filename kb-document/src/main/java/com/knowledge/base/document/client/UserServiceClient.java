package com.knowledge.base.document.client;

import com.knowledge.base.common.utils.UserContextUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
 * 用户服务客户端
 *
 * <p>通过 HTTP 调用 kb-user-auth 服务获取用户信息</p>
 */
@Slf4j
@Component
public class UserServiceClient {

    @Value("${kb-user-auth.url:http://localhost:8081}")
    private String userAuthUrl;

    private final RestTemplate restTemplate = new RestTemplate();

    /**
     * 获取用户头像URL
     *
     * <p>从当前请求上下文中获取 JWT Token 并传递到 kb-user-auth，
     * 如果 Token 不可用（如异步线程），则不带认证头请求（降级为空头像）。</p>
     */
    public String getUserAvatar(Long userId) {
        if (userId == null) {
            return null;
        }
        try {
            String url = userAuthUrl + "/users/" + userId;
            HttpHeaders headers = new HttpHeaders();
            String token = UserContextUtil.getToken();
            if (token != null && !token.isBlank()) {
                headers.set(HttpHeaders.AUTHORIZATION, buildBearerToken(token));
            }
            ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                    url,
                    HttpMethod.GET,
                    new HttpEntity<>(headers),
                    new ParameterizedTypeReference<Map<String, Object>>() {}
            );
            Map<String, Object> body = response.getBody();
            if (body != null && Integer.valueOf(200).equals(body.get("code"))) {
                @SuppressWarnings("unchecked")
                Map<String, Object> data = (Map<String, Object>) body.get("data");
                if (data != null && data.get("avatar") != null) {
                    return data.get("avatar").toString();
                }
            }
        } catch (Exception e) {
            log.warn("获取用户头像失败: userId={}, error={}", userId, e.getMessage());
        }
        return null;
    }

    /**
     * 获取用户权限编码列表。
     *
     * @param userId 用户ID
     * @param token  当前请求携带的JWT Token
     * @return 权限编码列表，查询失败时返回空集合
     */
    public List<String> getUserPermissions(Long userId, String token) {
        if (userId == null || token == null || token.isBlank()) {
            return Collections.emptyList();
        }
        try {
            String url = userAuthUrl + "/users/" + userId + "/permissions";
            HttpHeaders headers = new HttpHeaders();
            headers.set(HttpHeaders.AUTHORIZATION, buildBearerToken(token));
            ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                    url,
                    HttpMethod.GET,
                    new HttpEntity<>(headers),
                    new ParameterizedTypeReference<Map<String, Object>>() {}
            );
            Map<String, Object> body = response.getBody();
            if (body == null || !Integer.valueOf(200).equals(body.get("code"))) {
                return Collections.emptyList();
            }
            Object data = body.get("data");
            if (!(data instanceof List<?> rawList)) {
                return Collections.emptyList();
            }
            List<String> permissions = new ArrayList<>(rawList.size());
            for (Object item : rawList) {
                if (item != null) {
                    String permissionCode = item.toString().trim();
                    if (!permissionCode.isEmpty()) {
                        permissions.add(permissionCode);
                    }
                }
            }

            return permissions;
        } catch (Exception e) {
            log.warn("获取用户权限失败: userId={}, error={}", userId, e.getMessage());
            return Collections.emptyList();
        }
    }

    /**
     * 统一补齐 Bearer 前缀，避免下游认证失败。
     */
    private String buildBearerToken(String token) {
        return token.startsWith("Bearer ") ? token : "Bearer " + token;
    }
}
