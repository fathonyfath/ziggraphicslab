#version 330 core

struct Material {
    sampler2D diffuse;
    sampler2D specular;
    float shininess;
};

struct DirectionalLight {
    vec3 direction;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

struct PointLight {
    vec3 position;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    float constant;
    float linear;
    float quadratic;
};

struct SpotLight {
    vec3 position;
    vec3 direction;
    float cutOff;
    float outerCutOff;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    float constant;
    float linear;
    float quadratic;
};

in vec3 Normal;
in vec2 TexCoords;
in vec3 FragPos;

out vec4 FragColor;

uniform vec3 viewPos;
uniform Material material;
uniform DirectionalLight directionalLight;

#define NR_POINT_LIGHTS 4
uniform PointLight pointLights[NR_POINT_LIGHTS];

uniform SpotLight spotLight;

vec3 CalcDirectionalLight(DirectionalLight light, vec3 normal, vec3 viewDir);
vec3 CalcPointLight(PointLight light, vec3 normal, vec3 fragPos, vec3 viewDir);
vec3 CalcSpotLight(SpotLight light, vec3 normal, vec3 fragPos, vec3 viewDir);

void main() {
    vec3 normal = normalize(Normal);
    vec3 viewDir = normalize(viewPos - FragPos);

    vec3 output = vec3(0.0);
    
    // add directional light result
    output += CalcDirectionalLight(directionalLight, normal, viewDir);

    // add point lights result
    for (int i = 0; i < NR_POINT_LIGHTS; i++) {
        output += CalcPointLight(pointLights[i], normal, FragPos, viewDir);
    }

    // add spot light result
    output += CalcSpotLight(spotLight, normal, FragPos, viewDir);

    FragColor = vec4(output, 1.0);
}

vec3 CalcDirectionalLight(DirectionalLight light, vec3 normal, vec3 viewDir) {
    vec3 lightDir = normalize(-light.direction);

    // diffuse
    float diff = max(dot(normal, lightDir), 0.0);

    // specular
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);

    // combine
    vec3 ambient = light.ambient * vec3(texture(material.diffuse, TexCoords)).rgb;
    vec3 diffuse = light.diffuse * diff * vec3(texture(material.diffuse, TexCoords)).rgb;
    vec3 specular = light.specular * spec * vec3(texture(material.specular, TexCoords)).rgb;

    return (ambient + diffuse + specular);
}

vec3 CalcPointLight(PointLight light, vec3 normal, vec3 fragPos, vec3 viewDir) {
    vec3 lightDir = normalize(light.position - fragPos);

    // diffuse
    float diff = max(dot(normal, lightDir), 0.0);

    // specular
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);

    // attenuation
    float distance = length(light.position - fragPos);
    float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));

    // combine
    vec3 ambient = light.ambient * vec3(texture(material.diffuse, TexCoords)).rgb;
    vec3 diffuse = light.diffuse * diff * vec3(texture(material.diffuse, TexCoords)).rgb;
    vec3 specular = light.specular * spec * vec3(texture(material.specular, TexCoords)).rgb;
    
    ambient *= attenuation;
    diffuse *= attenuation;
    specular *= attenuation;

    return (ambient + diffuse + specular);
}

vec3 CalcSpotLight(SpotLight light, vec3 normal, vec3 fragPos, vec3 viewDir) {
    vec3 lightDir = normalize(light.position - fragPos);

    // diffuse
    float diff = max(dot(normal, lightDir), 0.0);

    // specular
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    
    // spotlight
    float theta = dot(lightDir, normalize(-light.direction));
    float epsilon = light.cutOff - light.outerCutOff;
    float intensity = clamp((theta - light.outerCutOff) / epsilon, 0.0, 1.0);

    // attenuation
    float distance = length(light.position - fragPos);
    float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));

    // combine
    vec3 ambient = light.ambient * vec3(texture(material.diffuse, TexCoords)).rgb;
    vec3 diffuse = light.diffuse * diff * vec3(texture(material.diffuse, TexCoords)).rgb;
    vec3 specular = light.specular * spec * vec3(texture(material.specular, TexCoords)).rgb;

    diffuse *= intensity;
    specular *= intensity;

    diffuse *= attenuation;
    specular *= attenuation;

    return (ambient + diffuse + specular);
}
