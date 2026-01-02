import { http } from '@kit.NetworkKit';
import { ApiConfig, ApiEndpoints, ApiHeaders, HttpStatus } from './ApiConfig';
import {
  PaginatedUsersResponse,
  SingleUserResponse,
  CreateUserResponseDto,
  UpdateUserResponseDto,
  UserDtoMapper
} from './dto/UserDto';
import { User, CreateUserRequest, UpdateUserRequest, PaginatedUsers } from '../../domain/models/User';
import { Result, ResultFactory } from '../../domain/models/Result';
import { AppError, AppErrorFactory } from '../../domain/models/AppError';
import { InterceptedHttpClient } from '../../core/network/HttpInterceptor';

const TAG = 'UserApiService';

/**
 * API service for user-related network operations.
 * Handles all HTTP communication with the reqres.in API.
 */
export class UserApiService {
  private httpClient: InterceptedHttpClient;

  constructor() {
    this.httpClient = new InterceptedHttpClient();
  }

  /**
   * Fetches paginated users from the API
   */
  async getUsers(page: number = 1): Promise<Result<PaginatedUsers, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.USERS}?page=${page}`;

    try {
      const response = await this.httpClient.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as PaginatedUsersResponse;
        return ResultFactory.success(UserDtoMapper.toPaginatedDomain(data));
      } else {
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      return ResultFactory.failure(this.handleError(error));
    }
  }

  /**
   * Fetches a single user by ID
   */
  async getUserById(userId: number): Promise<Result<User, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.userById(userId)}`;

    try {
      const response = await this.httpClient.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as SingleUserResponse;
        return ResultFactory.success(UserDtoMapper.toDomain(data.data));
      } else if (response.responseCode === HttpStatus.NOT_FOUND) {
        return ResultFactory.failure(AppErrorFactory.apiNotFound(`User ${userId}`));
      } else {
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      return ResultFactory.failure(this.handleError(error));
    }
  }

  /**
   * Creates a new user
   */
  async createUser(request: CreateUserRequest): Promise<Result<User, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.USERS}`;
    const body = UserDtoMapper.toCreateDto(request);

    try {
      const response = await this.httpClient.request(url, {
        method: http.RequestMethod.POST,
        header: this.getHeaders(),
        extraData: JSON.stringify(body),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.CREATED || response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as CreateUserResponseDto;
        return ResultFactory.success(UserDtoMapper.createResponseToDomain(data, request));
      } else {
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      return ResultFactory.failure(this.handleError(error));
    }
  }

  /**
   * Updates an existing user
   */
  async updateUser(request: UpdateUserRequest): Promise<Result<User, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.userById(request.id)}`;
    const body = UserDtoMapper.toUpdateDto(request);

    try {
      const response = await this.httpClient.request(url, {
        method: http.RequestMethod.PUT,
        header: this.getHeaders(),
        extraData: JSON.stringify(body),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as UpdateUserResponseDto;
        return ResultFactory.success(UserDtoMapper.updateResponseToDomain(data, request));
      } else if (response.responseCode === HttpStatus.NOT_FOUND) {
        return ResultFactory.failure(AppErrorFactory.apiNotFound(`User ${request.id}`));
      } else {
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      return ResultFactory.failure(this.handleError(error));
    }
  }

  /**
   * Deletes a user
   */
  async deleteUser(userId: number): Promise<Result<void, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.userById(userId)}`;

    try {
      const response = await this.httpClient.request(url, {
        method: http.RequestMethod.DELETE,
        header: this.getHeaders(),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.NO_CONTENT || response.responseCode === HttpStatus.OK) {
        return ResultFactory.success(undefined);
      } else if (response.responseCode === HttpStatus.NOT_FOUND) {
        return ResultFactory.failure(AppErrorFactory.apiNotFound(`User ${userId}`));
      } else {
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      return ResultFactory.failure(this.handleError(error));
    }
  }

  /**
   * Cleanup resources
   */
  destroy(): void {
    this.httpClient.destroy();
  }

  /**
   * Gets standard headers for API requests
   */
  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Content-Type'] = ApiHeaders.CONTENT_TYPE;
    headers['Accept'] = ApiHeaders.ACCEPT;
    headers['x-api-key'] = ApiConfig.API_KEY;
    return headers;
  }

  /**
   * Handles network errors and converts them to AppError
   */
  private handleError(error: Error | Object): AppError {
    if (error instanceof Error) {
      const message = error.message.toLowerCase();
      if (message.includes('timeout')) {
        return AppErrorFactory.networkTimeout();
      } else if (message.includes('network') || message.includes('connection')) {
        return AppErrorFactory.noConnection();
      }
      return AppErrorFactory.networkError(error.message, error);
    }
    return AppErrorFactory.unknown();
  }
}
