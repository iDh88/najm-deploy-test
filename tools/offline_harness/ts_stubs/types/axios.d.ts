// Offline structural stub for axios (surface used: axios.post + error shape).
declare module "axios" {
  export interface AxiosResponse<T = any> {
    data: T; status: number; headers: Record<string, string>;
  }
  export interface AxiosRequestConfig {
    headers?: Record<string, string>;
    timeout?: number;
    params?: Record<string, unknown>;
  }
  interface AxiosStatic {
    post<T = any>(url: string, data?: unknown, config?: AxiosRequestConfig): Promise<AxiosResponse<T>>;
    get<T = any>(url: string, config?: AxiosRequestConfig): Promise<AxiosResponse<T>>;
  }
  const axios: AxiosStatic;
  export default axios;
}
